// trilha — a study app for the Infra & DevOps learning path: lessons,
// glossary, flashcards, quizzes and a checklist, following the Omarchy theme.

#include <QCoreApplication>
#include <QFont>
#include <QGuiApplication>
#include <QIcon>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QUrl>
#include <cstdio>
#include <cstring>

#include "backend.h"
#include "theme.h"

namespace {
void print(FILE *stream, const QString &text) {
    std::fputs(text.toUtf8().constData(), stream);
    std::fputs("\n", stream);
}

const char *kUsage =
    "uso: trilha [open]            abre o app\n"
    "     trilha check [--json]    valida o conteúdo (lições, glossário, quiz, trilha)\n"
    "     trilha progress          mostra o progresso salvo, em JSON";

// Commands that need no display, so an agent can check content and read
// progress: exit 0 on success, 1 with the problem on stderr.
int runCommand(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    app.setApplicationName("trilha");
    const QStringList args = app.arguments();
    const QString command = args.value(1);
    const bool json = args.contains("--json");
    Backend backend(":/content", {}, nullptr, Backend::localContentDirectory());

    if (command == "check") {
        const QStringList problems = backend.validate();
        if (json) {
            print(stdout, QJsonDocument(QJsonObject{{"ok", problems.isEmpty()},
                                                    {"problemas", QJsonArray::fromStringList(problems)},
                                                    {"licoes", backend.lessonsTotal()},
                                                    {"termos", backend.glossary().size()},
                                                    {"perguntas", backend.questionsTotal()},
                                                    {"itens", backend.itemsTotal()},
                                                    {"conteudoProprio", QJsonArray::fromStringList(backend.overriddenFiles())}})
                              .toJson(QJsonDocument::Compact));
        } else if (problems.isEmpty()) {
            for (const auto &file : backend.overriddenFiles())
                print(stdout, QString("Usando conteúdo próprio: %1").arg(file));
            print(stdout, QString("Conteúdo ok: %1 lições, %2 termos, %3 perguntas, %4 itens da trilha.")
                              .arg(backend.lessonsTotal())
                              .arg(backend.glossary().size())
                              .arg(backend.questionsTotal())
                              .arg(backend.itemsTotal()));
        }
        for (const auto &problem : problems)
            print(stderr, problem);
        return problems.isEmpty() ? 0 : 1;
    }
    if (command == "progress") {
        print(stdout, QJsonDocument(backend.summary()).toJson(QJsonDocument::Indented).trimmed());
        return 0;
    }
    if (command == "help" || command == "--help" || command == "-h") {
        print(stdout, kUsage);
        return 0;
    }
    print(stderr, kUsage);
    return 1;
}
}

int main(int argc, char *argv[]) {
    if (argc > 1 && std::strcmp(argv[1], "open") != 0)
        return runCommand(argc, argv);

    QGuiApplication app(argc, argv);
    app.setApplicationName("trilha");
    app.setApplicationVersion("0.1.0");

    // Matches the window to trilha.desktop, so the compositor (Wayland app_id)
    // and the launcher pick up the installed icon.
    app.setDesktopFileName("trilha");
    app.setWindowIcon(QIcon::fromTheme("trilha", QIcon(":/trilha.png")));

    QQuickStyle::setStyle("Material");

    Theme theme;
    app.setFont(QFont(theme.sans()));
    Backend backend(":/content", {}, nullptr, Backend::localContentDirectory());
    backend.setMonoFont(theme.mono());

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
