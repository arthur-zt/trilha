#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

#include "backend.h"
#include "theme.h"

class TrilhaTests : public QObject {
    Q_OBJECT

private slots:
    void contentIsValid()
    {
        QTemporaryDir dir;
        Backend backend(":/content", dir.filePath("p.json"));
        const QStringList problems = backend.validate();
        QVERIFY2(problems.isEmpty(), qPrintable(problems.join('\n')));
        QVERIFY(backend.lessonsTotal() > 20);
        QVERIFY(backend.glossary().size() > 50);
        QVERIFY(backend.questionsTotal() > 40);
    }

    void checklistPersists()
    {
        QTemporaryDir dir;
        const QString file = dir.filePath("p.json");
        {
            Backend backend(":/content", file);
            QVERIFY(!backend.isDone("f1-zines"));
            backend.toggleItem("f1-zines");
            QVERIFY(backend.isDone("f1-zines"));
            QCOMPARE(backend.itemsDone(), 1);
        }
        Backend reopened(":/content", file);
        QVERIFY(reopened.isDone("f1-zines"));
        QCOMPARE(reopened.phaseDone("f1"), 1);
        reopened.toggleItem("f1-zines");
        QVERIFY(!reopened.isDone("f1-zines"));
        reopened.toggleItem("nao-existe");
        QCOMPARE(reopened.itemsDone(), 0);
    }

    void localContentOverridesBuiltIn()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("conteudo");
        QFile builtIn(":/content/trilha.json");
        QVERIFY(builtIn.open(QIODevice::ReadOnly));
        QByteArray json = builtIn.readAll();
        json.replace("\"diagnostico\":", "\"diagnostico\": \"meu diagnóstico\", \"x\":");
        write(dir.filePath("conteudo/trilha.json"), json);

        Backend backend(":/content", dir.filePath("p.json"), nullptr, dir.filePath("conteudo"));
        QVERIFY(backend.customContent());
        QCOMPARE(backend.overriddenFiles().size(), 1);
        QCOMPARE(backend.diagnosis(), QString("meu diagnóstico"));
        QVERIFY(backend.validate().isEmpty());

        Backend plain(":/content", dir.filePath("p.json"));
        QVERIFY(!plain.customContent());
    }

    void unreadableProgressIsKept()
    {
        QTemporaryDir dir;
        const QString file = dir.filePath("p.json");
        write(file, "{ isto não é json");
        Backend backend(":/content", file);
        QVERIFY(!backend.error().isEmpty());
        QVERIFY(QFile::exists(file + ".corrompido"));
    }

    void lessonsLinkInOrder()
    {
        QTemporaryDir dir;
        Backend backend(":/content", dir.filePath("p.json"));
        const QString first = backend.firstLessonOf("cap-redes");
        const QVariantMap lesson = backend.lesson(first);
        QCOMPARE(lesson.value("anterior").toString(), QString());
        QVERIFY(!lesson.value("proxima").toString().isEmpty());
        QCOMPARE(lesson.value("posicao").toInt(), 1);
        backend.setRead(first, true);
        QCOMPARE(backend.readCount(), 1);
        QCOMPARE(backend.chapterRead("cap-redes"), 1);
        backend.openLesson(first);
        QCOMPARE(backend.lastLesson(), first);
    }

    void cardsClimbTheBoxes()
    {
        QTemporaryDir dir;
        Backend backend(":/content", dir.filePath("p.json"));
        backend.setToday(QDate(2026, 11, 17));
        const int total = backend.glossary().size();
        QCOMPARE(backend.dueCount(), total);
        const QString term = backend.glossary().first().toMap().value("termo").toString();

        backend.answerCard(term, true);
        QCOMPARE(backend.cardBox(term), 1);
        QCOMPARE(backend.dueCount(), total - 1);

        backend.setToday(QDate(2026, 11, 18));
        QCOMPARE(backend.dueCount(), total);
        backend.answerCard(term, true);
        QCOMPARE(backend.cardBox(term), 2);

        backend.setToday(QDate(2026, 11, 21));
        backend.answerCard(term, false);
        QCOMPARE(backend.cardBox(term), 1);
        QCOMPARE(backend.boxCounts().at(1).toInt(), 1);
        QCOMPARE(backend.dueCards(500).size(), total - 1);
    }

    void quizKeepsTheBestScore()
    {
        QTemporaryDir dir;
        Backend backend(":/content", dir.filePath("p.json"));
        backend.recordQuiz("cap-redes", 5, 8);
        backend.recordQuiz("cap-redes", 3, 8);
        const QVariantMap stats = backend.quizStats("cap-redes");
        QCOMPARE(stats.value("melhor").toInt(), 5);
        QCOMPARE(stats.value("ultima").toInt(), 3);
        QCOMPARE(stats.value("tentativas").toInt(), 2);
        QVERIFY(backend.quiz("").size() >= backend.quiz("cap-redes").size());
    }

    void searchIgnoresAccents()
    {
        QTemporaryDir dir;
        Backend backend(":/content", dir.filePath("p.json"));
        bool foundTerm = false;
        for (const auto &hit : backend.search("sni"))
            foundTerm |= hit.toMap().value("tipo") == "termo" && hit.toMap().value("titulo") == "SNI";
        QVERIFY(foundTerm);
        bool foundLesson = false;
        for (const auto &hit : backend.search("replicacao"))
            foundLesson |= hit.toMap().value("alvo") == "l-repl";
        QVERIFY(foundLesson);
        QVERIFY(backend.search("x").isEmpty());
    }

    void markupBecomesStyledText()
    {
        Backend backend(":/content", QTemporaryDir().filePath("p.json"));
        QCOMPARE(backend.rich("**a** e *b*", "#fff"), QString("<b>a</b> e <i>b</i>"));
        const QString code = backend.rich("`/opt/app_*` <x>", "#123456");
        QVERIFY(code.contains("color=\"#123456\">/opt/app_*</font>"));
        QVERIFY(code.contains("&lt;x&gt;"));
        QVERIFY(!code.contains("<i>"));
        QCOMPARE(backend.rich("**o `ls -l` mostra**", "#000"),
                 QString("<b>o <font face=\"JetBrainsMono Nerd Font\" color=\"#000\">ls -l</font> mostra</b>"));
        QCOMPARE(backend.codeHtml("ls -l  # lista", "#999"),
                 QString("ls&nbsp;-l&nbsp;&nbsp;<font color=\"#999\">#&nbsp;lista</font>"));
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QColor("#FFD60A"));
        QCOMPARE(theme.accentForeground(), QColor("black"));
        QVERIFY(theme.dark());
    }

    void themeReadsColors()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        write(dir.path() + "/theme/colors.toml",
              "mode = \"light\"\naccent = \"#112233\"\nbackground = \"#fafafa\"\n");
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QColor("#112233"));
        QCOMPARE(theme.accentForeground(), QColor("white"));
        QCOMPARE(theme.background(), QColor("#fafafa"));
        QVERIFY(!theme.dark());
    }

private:
    static void write(const QString &path, const QByteArray &contents)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(contents);
    }
};

QTEST_MAIN(TrilhaTests)
#include "trilha_tests.moc"
