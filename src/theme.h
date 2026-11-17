#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QHash>
#include <QObject>
#include <QProcess>
#include <QTimer>

// Follows the Omarchy theme live: the accent plus the background and text
// colors, so the app looks like the rest of the desktop after a theme switch.
class Theme : public QObject {
    Q_OBJECT
    Q_PROPERTY(QColor accent READ accent NOTIFY changed)
    Q_PROPERTY(QColor accentForeground READ accentForeground NOTIFY changed)
    Q_PROPERTY(QColor background READ background NOTIFY changed)
    Q_PROPERTY(QColor surface READ surface NOTIFY changed)
    Q_PROPERTY(QColor raised READ raised NOTIFY changed)
    Q_PROPERTY(QColor foreground READ foreground NOTIFY changed)
    Q_PROPERTY(QColor subtle READ subtle NOTIFY changed)
    Q_PROPERTY(QColor border READ border NOTIFY changed)
    Q_PROPERTY(bool dark READ dark NOTIFY changed)
    Q_PROPERTY(int radius READ radius NOTIFY changed)
    // Semantic colors stay fixed across themes: they mean right, wrong,
    // "real environment" and "information", not decoration.
    Q_PROPERTY(QColor ok READ ok CONSTANT)
    Q_PROPERTY(QColor danger READ danger CONSTANT)
    Q_PROPERTY(QColor warn READ warn CONSTANT)
    Q_PROPERTY(QColor info READ info CONSTANT)
    Q_PROPERTY(QString mono READ mono CONSTANT)
    Q_PROPERTY(QString sans READ sans CONSTANT)

public:
    explicit Theme(const QString &currentDirectory = {}, QObject *parent = nullptr, const QString &hyprctl = {});
    ~Theme() override;

    QColor accent() const { return color("accent"); }
    QColor accentForeground() const;
    QColor background() const { return color("background"); }
    QColor surface() const { return color("lighter_background"); }
    QColor raised() const { return surface().lighter(dark() ? 135 : 96); }
    QColor foreground() const { return color("foreground"); }
    QColor subtle() const { return color("light_foreground"); }
    QColor border() const { return color("muted"); }
    bool dark() const { return m_mode != "light"; }
    int radius() const { return m_radius; }
    QColor ok() const { return QColor("#4cbb7f"); }
    QColor danger() const { return QColor("#e5534b"); }
    QColor warn() const { return QColor("#e0a84a"); }
    QColor info() const { return QColor("#7aa2f7"); }
    // Omarchy's fonts when they are installed, the system's otherwise, so the
    // app reads the same on Windows and macOS.
    QString mono() const { return m_mono; }
    QString sans() const { return m_sans; }

    // Reads every `key = "#rrggbb"` line of an Omarchy colors.toml.
    static QHash<QString, QString> readColors(const QString &path, QString *mode = nullptr);

signals:
    void changed();

private:
    QColor color(const QString &key) const;
    void reload();
    void refreshRounding();

    QString m_directory;
    QString m_mono, m_sans;
    QHash<QString, QString> m_colors;
    QString m_mode = "dark";
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
    QString m_hyprctl;
    int m_radius = 0;
    QProcess m_roundingProcess;
    QTimer m_roundingPoll, m_roundingTimeout;
};
