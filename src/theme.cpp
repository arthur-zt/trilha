// Theme watching follows Omacut (MIT, David Heinemeier Hansson).
#include "theme.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QStandardPaths>
#include <cmath>

namespace {
// Used when Omarchy isn't there, or a theme leaves a color out.
const QHash<QString, QString> &fallbackColors() {
    static const QHash<QString, QString> colors{
        {"accent", "#FFD60A"},
        {"background", "#121212"},
        {"lighter_background", "#1b1b1d"},
        {"foreground", "#e6e6e6"},
        {"light_foreground", "#9a9a9a"},
        {"muted", "#2c2c30"},
    };
    return colors;
}
}

Theme::Theme(const QString &directory, QObject *parent, const QString &hyprctl)
    : QObject(parent),
      m_directory(directory.isEmpty() ? QDir::homePath() + "/.local/state/omarchy/current" : directory) {
    auto pick = [](const QStringList &wanted, QFontDatabase::SystemFont fallback) {
        if (!qobject_cast<QGuiApplication *>(QCoreApplication::instance()))
            return wanted.first();
        const QStringList installed = QFontDatabase::families();
        for (const auto &family : wanted)
            if (installed.contains(family))
                return family;
        return QFontDatabase::systemFont(fallback).family();
    };
    m_mono = pick({"JetBrainsMono Nerd Font", "JetBrains Mono", "Cascadia Mono", "Consolas", "SF Mono", "Menlo",
                   "DejaVu Sans Mono"}, QFontDatabase::FixedFont);
    m_sans = pick({"Noto Sans", "Segoe UI", "SF Pro Text", "Helvetica Neue", "Ubuntu", "Cantarell"},
                  QFontDatabase::GeneralFont);
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(80);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_debounce, &QTimer::timeout, this, &Theme::reload);

    // Corners follow Hyprland's effective rounding, which themes and personal
    // overrides can both set, so ask hyprctl rather than reading its config.
    // Without Hyprland the corners stay sharp, like Omarchy's default.
    m_hyprctl = !hyprctl.isEmpty() ? hyprctl
              : directory.isEmpty() && !qEnvironmentVariableIsEmpty("HYPRLAND_INSTANCE_SIGNATURE")
                  ? QStandardPaths::findExecutable("hyprctl") : QString();
    m_roundingTimeout.setSingleShot(true);
    m_roundingTimeout.setInterval(500);
    connect(&m_roundingTimeout, &QTimer::timeout, &m_roundingProcess, &QProcess::kill);
    connect(&m_roundingProcess, &QProcess::errorOccurred, this, [this] { m_roundingTimeout.stop(); });
    connect(&m_roundingProcess, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        m_roundingTimeout.stop();
        const auto value = QJsonDocument::fromJson(m_roundingProcess.readAllStandardOutput()).object().value("int");
        if (code != 0 || status != QProcess::NormalExit || !value.isDouble() || value.toInt(-1) < 0)
            return;
        if (value.toInt() != m_radius) {
            m_radius = value.toInt();
            emit changed();
        }
    });
    m_roundingPoll.setInterval(1000);
    connect(&m_roundingPoll, &QTimer::timeout, this, &Theme::refreshRounding);
    if (!m_hyprctl.isEmpty())
        m_roundingPoll.start();
    reload();
}

Theme::~Theme() {
    if (m_roundingProcess.state() != QProcess::NotRunning) {
        m_roundingProcess.kill();
        m_roundingProcess.waitForFinished(1000);
    }
}

void Theme::refreshRounding() {
    if (m_hyprctl.isEmpty() || m_roundingProcess.state() != QProcess::NotRunning)
        return;
    m_roundingProcess.start(m_hyprctl, {"-j", "getoption", "decoration:rounding"});
    m_roundingTimeout.start();
}

QHash<QString, QString> Theme::readColors(const QString &path, QString *mode) {
    QHash<QString, QString> colors;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return colors;
    const QString text = QString::fromUtf8(file.readAll());
    static const QRegularExpression colorLine(R"re(^\s*([a-z_]+)\s*=\s*["'](#[0-9a-fA-F]{6})["'])re",
                                              QRegularExpression::MultilineOption);
    for (auto it = colorLine.globalMatch(text); it.hasNext();) {
        const auto match = it.next();
        colors.insert(match.captured(1), match.captured(2));
    }
    static const QRegularExpression modeLine(R"re(^\s*mode\s*=\s*["'](\w+)["'])re", QRegularExpression::MultilineOption);
    if (mode) {
        const auto match = modeLine.match(text);
        *mode = match.hasMatch() ? match.captured(1) : QString("dark");
    }
    return colors;
}

QColor Theme::color(const QString &key) const {
    return QColor(m_colors.value(key, fallbackColors().value(key, "#ff00ff")));
}

// Black or white, whichever reads on the accent (WCAG relative luminance).
QColor Theme::accentForeground() const {
    const QColor c = accent();
    auto linear = [](double v) { return v <= .04045 ? v / 12.92 : std::pow((v + .055) / 1.055, 2.4); };
    const double luminance = .2126 * linear(c.redF()) + .7152 * linear(c.greenF()) + .0722 * linear(c.blueF());
    return QColor(luminance > .179 ? "black" : "white");
}

void Theme::reload() {
    refreshRounding();
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);

    // A theme switch replaces symlinks and files, so watch the parents too and
    // re-arm after every change. Watching the nearest existing ancestor means
    // installing Omarchy later works without restarting the app.
    QString ancestor = m_directory;
    while (!QFileInfo::exists(ancestor) && ancestor != "/")
        ancestor = QFileInfo(ancestor).absolutePath();
    QStringList candidates{ancestor, QFileInfo(ancestor).absolutePath(), m_directory,
                           m_directory + "/theme", m_directory + "/theme/colors.toml"};
    candidates.removeDuplicates();
    for (const auto &path : candidates)
        if (QFileInfo::exists(path))
            m_watcher.addPath(path);

    QString mode;
    const auto colors = readColors(m_directory + "/theme/colors.toml", &mode);
    if (colors != m_colors || mode != m_mode) {
        m_colors = colors;
        m_mode = mode;
        emit changed();
    }
}
