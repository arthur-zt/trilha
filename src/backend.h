#pragma once

#include <QDate>
#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QStringList>
#include <QVariant>

// The study content (compiled in as JSON) and the user's progress (a JSON
// file in ~/.local/share/trilha), exposed to QML as `backend`. Every change
// to progress bumps `revision`, which QML bindings read to re-evaluate.
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList phases READ phases CONSTANT)
    Q_PROPERTY(QVariantList chapters READ chapters CONSTANT)
    Q_PROPERTY(QVariantList lessonIndex READ lessonIndex CONSTANT)
    Q_PROPERTY(QVariantList glossary READ glossary CONSTANT)
    Q_PROPERTY(QVariantList extras READ extras CONSTANT)
    Q_PROPERTY(QString diagnosis READ diagnosis CONSTANT)
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(QString lastLesson READ lastLesson NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(bool customContent READ customContent CONSTANT)

public:
    // `overrideDirectory` holds the person's own copies of the content files;
    // each one found there replaces the built-in file of the same name.
    explicit Backend(const QString &contentDirectory = ":/content", const QString &progressFile = {},
                     QObject *parent = nullptr, const QString &overrideDirectory = {});

    QVariantList phases() const { return m_phases; }
    QVariantList chapters() const { return m_chapters; }
    QVariantList lessonIndex() const { return m_lessonIndex; }
    QVariantList glossary() const { return m_glossary; }
    QVariantList extras() const { return m_extras; }
    QString diagnosis() const { return m_diagnosis; }
    int revision() const { return m_revision; }
    QString lastLesson() const { return m_progress.value("ultimaLicao").toString(); }
    QString error() const { return m_error; }
    bool customContent() const { return !m_overridden.isEmpty(); }
    QStringList overriddenFiles() const { return m_overridden; }
    QString progressPath() const { return m_progressPath; }

    // Trilha checklist.
    Q_INVOKABLE void toggleItem(const QString &id);
    Q_INVOKABLE bool isDone(const QString &id) const;
    Q_INVOKABLE QString doneDate(const QString &id) const;
    Q_INVOKABLE int itemsDone() const;
    Q_INVOKABLE int itemsTotal() const { return m_itemIds.size(); }
    Q_INVOKABLE int phaseDone(const QString &phaseId) const;
    Q_INVOKABLE QVariantList nextItems(int count) const;

    // Apostila.
    Q_INVOKABLE QVariantMap lesson(const QString &id) const;
    Q_INVOKABLE QString firstLessonOf(const QString &chapterId) const;
    Q_INVOKABLE void openLesson(const QString &id);
    Q_INVOKABLE void setRead(const QString &id, bool read);
    Q_INVOKABLE bool isRead(const QString &id) const;
    Q_INVOKABLE int readCount() const;
    Q_INVOKABLE int lessonsTotal() const { return m_lessonOrder.size(); }
    Q_INVOKABLE int chapterRead(const QString &chapterId) const;

    // Quiz.
    Q_INVOKABLE QVariantList quiz(const QString &chapterId) const;
    Q_INVOKABLE void recordQuiz(const QString &chapterId, int score, int total);
    Q_INVOKABLE QVariantMap quizStats(const QString &chapterId) const;
    Q_INVOKABLE int questionsTotal() const;

    // Flashcards: a Leitner system over the glossary.
    Q_INVOKABLE QVariantList dueCards(int limit) const;
    Q_INVOKABLE QVariantList randomCards(int limit) const;
    Q_INVOKABLE int dueCount() const;
    Q_INVOKABLE QVariantList boxCounts() const;
    Q_INVOKABLE void answerCard(const QString &term, bool knew);
    Q_INVOKABLE int cardBox(const QString &term) const;

    // Search, text and clipboard helpers.
    Q_INVOKABLE QVariantList search(const QString &query) const;
    Q_INVOKABLE QString rich(const QString &text, const QString &codeColor) const;
    Q_INVOKABLE QString codeHtml(const QString &text, const QString &commentColor) const;
    Q_INVOKABLE QString normalizeText(const QString &text) const { return normalize(text); }
    Q_INVOKABLE void copy(const QString &text) const;

    // For the command line and the tests.
    QStringList validate() const;
    QJsonObject summary() const;
    void setToday(const QDate &today) { m_today = today; }
    void setMonoFont(const QString &family) { m_mono = family; }
    static QString localContentDirectory();
    static QString normalize(const QString &text);
    static QString plain(const QString &markup);
    static int intervalDays(int box);

signals:
    void changed();

private:
    struct ChapterRef {
        QString id, title;
        int number = 0;
    };

    void load();
    void loadProgress();
    void commit();
    QJsonObject section(const QString &key) const { return m_progress.value(key).toObject(); }
    bool cardDue(const QString &term) const;
    QVariantMap termMap(const QString &term) const;

    QString m_contentDirectory;
    QString m_overrideDirectory;
    QStringList m_overridden;
    QString m_mono = "JetBrainsMono Nerd Font";
    QString m_progressPath;
    QString m_error;
    QStringList m_loadErrors;
    QDate m_today = QDate::currentDate();
    int m_revision = 0;

    QJsonObject m_progress;
    QJsonArray m_phasesJson, m_chaptersJson, m_glossaryJson, m_quizJson;
    QVariantList m_phases, m_chapters, m_lessonIndex, m_glossary, m_extras;
    QString m_diagnosis;
    QStringList m_itemIds, m_lessonOrder;
    QHash<QString, QString> m_itemText, m_itemPhase, m_phaseTitle;
    QHash<QString, QJsonObject> m_lessons;
    QHash<QString, ChapterRef> m_lessonChapter;
    QHash<QString, QString> m_lessonText;
    QHash<QString, QVariantMap> m_terms;
    QHash<QString, QJsonArray> m_quizzes;
};
