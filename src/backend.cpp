#include "backend.h"

#include <QClipboard>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <algorithm>

namespace {
QJsonObject readJson(const QString &path, QStringList &errors) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        errors << QString("Não consegui abrir %1").arg(path);
        return {};
    }
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(file.readAll(), &parse);
    if (parse.error != QJsonParseError::NoError || !document.isObject()) {
        errors << QString("%1: %2 (posição %3)").arg(QFileInfo(path).fileName(), parse.errorString()).arg(parse.offset);
        return {};
    }
    return document.object();
}

QString escapeHtml(QString text) {
    text.replace('&', "&amp;");
    text.replace('<', "&lt;");
    text.replace('>', "&gt;");
    return text;
}

QString blockText(const QJsonObject &block) {
    QStringList parts{block.value("titulo").toString(), block.value("texto").toString()};
    for (const auto &item : block.value("itens").toArray())
        parts << item.toString();
    for (const auto &column : block.value("colunas").toArray())
        parts << column.toString();
    for (const auto &row : block.value("linhas").toArray())
        for (const auto &cell : row.toArray())
            parts << cell.toString();
    parts.removeAll(QString());
    return Backend::plain(parts.join(' '));
}

// A short excerpt of `text` around the first match of the normalized query.
QString excerpt(const QString &text, const QString &normalizedQuery) {
    const QString normalized = Backend::normalize(text);
    int at = normalized.indexOf(normalizedQuery);
    if (at < 0 || normalized.size() != text.size())
        return text.left(110).simplified() + (text.size() > 110 ? "…" : "");
    const int start = std::max(0, at - 45);
    QString piece = text.mid(start, 120).simplified();
    return (start > 0 ? "…" : "") + piece + (start + 120 < text.size() ? "…" : "");
}
}

Backend::Backend(const QString &contentDirectory, const QString &progressFile, QObject *parent,
                 const QString &overrideDirectory)
    : QObject(parent),
      m_contentDirectory(contentDirectory),
      m_overrideDirectory(overrideDirectory),
      m_progressPath(progressFile.isEmpty()
                         ? QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/progresso.json"
                         : progressFile) {
    load();
    loadProgress();
}

QString Backend::localContentDirectory() {
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/conteudo";
}

QString Backend::normalize(const QString &text) {
    const QString decomposed = text.normalized(QString::NormalizationForm_D);
    QString out;
    out.reserve(decomposed.size());
    for (const QChar c : decomposed)
        if (c.category() != QChar::Mark_NonSpacing)
            out += c.toLower();
    return out;
}

QString Backend::plain(const QString &markup) {
    QString text = markup;
    text.remove('`');
    text.remove("**");
    static const QRegularExpression italic(R"((?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*]))");
    text.replace(italic, "\\1");
    return text;
}

int Backend::intervalDays(int box) {
    static const int days[] = {0, 1, 3, 7, 14, 30};
    return days[std::clamp(box, 0, 5)];
}

void Backend::load() {
    m_loadErrors.clear();
    m_overridden.clear();
    auto source = [this](const QString &name) {
        const QString local = m_overrideDirectory + "/" + name;
        if (!m_overrideDirectory.isEmpty() && QFileInfo::exists(local)) {
            m_overridden << local;
            return local;
        }
        return m_contentDirectory + "/" + name;
    };
    const auto trilha = readJson(source("trilha.json"), m_loadErrors);
    const auto apostila = readJson(source("apostila.json"), m_loadErrors);
    const auto glossario = readJson(source("glossario.json"), m_loadErrors);
    const auto quiz = readJson(source("quiz.json"), m_loadErrors);

    m_diagnosis = trilha.value("diagnostico").toString();
    m_extras = trilha.value("extras").toArray().toVariantList();
    m_phasesJson = trilha.value("fases").toArray();
    m_phases = m_phasesJson.toVariantList();
    for (const auto &phaseValue : m_phasesJson) {
        const auto phase = phaseValue.toObject();
        m_phaseTitle.insert(phase.value("id").toString(), phase.value("titulo").toString());
        for (const auto &itemValue : phase.value("itens").toArray()) {
            const auto item = itemValue.toObject();
            const QString id = item.value("id").toString();
            m_itemIds << id;
            m_itemText.insert(id, item.value("texto").toString() + " " + item.value("sub").toString());
            m_itemPhase.insert(id, phase.value("id").toString());
        }
    }

    m_chaptersJson = apostila.value("capitulos").toArray();
    for (const auto &chapterValue : m_chaptersJson) {
        const auto chapter = chapterValue.toObject();
        const ChapterRef ref{chapter.value("id").toString(), chapter.value("titulo").toString(),
                             chapter.value("numero").toInt()};
        const auto lessons = chapter.value("licoes").toArray();
        m_chapters << QVariantMap{{"id", ref.id},
                                  {"numero", ref.number},
                                  {"titulo", ref.title},
                                  {"subtitulo", chapter.value("subtitulo").toString()},
                                  {"resumo", chapter.value("resumo").toString()},
                                  {"licoes", lessons.size()}};
        m_lessonIndex << QVariantMap{{"tipo", "cap"}, {"id", ref.id}, {"numero", ref.number}, {"titulo", ref.title}};
        for (const auto &lessonValue : lessons) {
            const auto lesson = lessonValue.toObject();
            const QString id = lesson.value("id").toString();
            m_lessonOrder << id;
            m_lessons.insert(id, lesson);
            m_lessonChapter.insert(id, ref);
            QStringList text;
            for (const auto &block : lesson.value("blocos").toArray())
                text << blockText(block.toObject());
            m_lessonText.insert(id, text.join(' '));
            m_lessonIndex << QVariantMap{{"tipo", "licao"}, {"id", id}, {"titulo", lesson.value("titulo").toString()},
                                         {"capitulo", ref.id}};
        }
    }

    m_glossaryJson = glossario.value("termos").toArray();
    QList<QVariantMap> terms;
    for (const auto &termValue : m_glossaryJson) {
        auto map = termValue.toObject().toVariantMap();
        const QString term = map.value("termo").toString();
        const QString normalized = normalize(term);
        map.insert("letra", normalized.isEmpty() ? QString("#") : normalized.left(1).toUpper());
        map.insert("busca", normalize(term + " " + map.value("nome").toString() + " " + map.value("categoria").toString()
                                      + " " + plain(map.value("definicao").toString())));
        terms << map;
        m_terms.insert(term, map);
    }
    std::sort(terms.begin(), terms.end(), [](const QVariantMap &a, const QVariantMap &b) {
        return normalize(a.value("termo").toString()) < normalize(b.value("termo").toString());
    });
    for (const auto &map : terms)
        m_glossary << map;

    m_quizJson = quiz.value("quizzes").toArray();
    for (const auto &quizValue : m_quizJson) {
        const auto object = quizValue.toObject();
        m_quizzes.insert(object.value("capitulo").toString(), object.value("perguntas").toArray());
    }

    m_error = m_loadErrors.join('\n');
}

void Backend::loadProgress() {
    QFile file(m_progressPath);
    if (!file.exists())
        return;
    if (!file.open(QIODevice::ReadOnly)) {
        m_error = QString("Não consegui ler o progresso em %1").arg(m_progressPath);
        return;
    }
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(file.readAll(), &parse);
    if (parse.error != QJsonParseError::NoError || !document.isObject()) {
        // Never overwrite a file we could not understand: keep a copy beside it.
        QFile::copy(m_progressPath, m_progressPath + ".corrompido");
        m_error = QString("O arquivo de progresso estava ilegível; guardei uma cópia em %1.corrompido")
                      .arg(m_progressPath);
        return;
    }
    m_progress = document.object();
}

void Backend::commit() {
    ++m_revision;
    // Written beside the target and renamed over it, so a crash never leaves
    // half a file behind.
    QDir().mkpath(QFileInfo(m_progressPath).absolutePath());
    QSaveFile file(m_progressPath);
    if (!file.open(QIODevice::WriteOnly) || file.write(QJsonDocument(m_progress).toJson()) < 0 || !file.commit())
        m_error = QString("Não consegui salvar o progresso em %1").arg(m_progressPath);
    emit changed();
}

// --- Trilha -----------------------------------------------------------------

void Backend::toggleItem(const QString &id) {
    if (!m_itemIds.contains(id))
        return;
    auto done = section("trilha");
    if (done.contains(id))
        done.remove(id);
    else
        done.insert(id, m_today.toString(Qt::ISODate));
    m_progress.insert("trilha", done);
    commit();
}

bool Backend::isDone(const QString &id) const { return section("trilha").contains(id); }

QString Backend::doneDate(const QString &id) const {
    const QDate date = QDate::fromString(section("trilha").value(id).toString(), Qt::ISODate);
    return date.isValid() ? date.toString("dd/MM") : QString();
}

int Backend::itemsDone() const {
    int count = 0;
    for (const auto &id : m_itemIds)
        count += isDone(id);
    return count;
}

int Backend::phaseDone(const QString &phaseId) const {
    int count = 0;
    for (const auto &id : m_itemIds)
        count += m_itemPhase.value(id) == phaseId && isDone(id);
    return count;
}

QVariantList Backend::nextItems(int count) const {
    QVariantList items;
    for (const auto &phaseValue : m_phasesJson) {
        const auto phase = phaseValue.toObject();
        for (const auto &itemValue : phase.value("itens").toArray()) {
            auto item = itemValue.toObject().toVariantMap();
            if (isDone(item.value("id").toString()))
                continue;
            item.insert("fase", phase.value("titulo").toString());
            items << item;
            if (items.size() >= count)
                return items;
        }
    }
    return items;
}

// --- Apostila ---------------------------------------------------------------

QVariantMap Backend::lesson(const QString &id) const {
    if (!m_lessons.contains(id))
        return {};
    const auto lesson = m_lessons.value(id);
    const auto chapter = m_lessonChapter.value(id);
    const int at = m_lessonOrder.indexOf(id);
    QStringList siblings;
    for (const auto &other : m_lessonOrder)
        if (m_lessonChapter.value(other).id == chapter.id)
            siblings << other;
    const QString previous = at > 0 ? m_lessonOrder.at(at - 1) : QString();
    const QString next = at + 1 < m_lessonOrder.size() ? m_lessonOrder.at(at + 1) : QString();
    return {{"id", id},
            {"titulo", lesson.value("titulo").toString()},
            {"blocos", lesson.value("blocos").toArray().toVariantList()},
            {"capituloId", chapter.id},
            {"capituloTitulo", chapter.title},
            {"capituloNumero", chapter.number},
            {"posicao", siblings.indexOf(id) + 1},
            {"totalCapitulo", siblings.size()},
            {"anterior", previous},
            {"anteriorTitulo", m_lessons.value(previous).value("titulo").toString()},
            {"proxima", next},
            {"proximaTitulo", m_lessons.value(next).value("titulo").toString()}};
}

QString Backend::firstLessonOf(const QString &chapterId) const {
    for (const auto &id : m_lessonOrder)
        if (m_lessonChapter.value(id).id == chapterId)
            return id;
    return m_lessonOrder.value(0);
}

void Backend::openLesson(const QString &id) {
    if (!m_lessons.contains(id) || lastLesson() == id)
        return;
    m_progress.insert("ultimaLicao", id);
    commit();
}

void Backend::setRead(const QString &id, bool read) {
    if (!m_lessons.contains(id) || isRead(id) == read)
        return;
    auto lidas = section("lidas");
    if (read)
        lidas.insert(id, m_today.toString(Qt::ISODate));
    else
        lidas.remove(id);
    m_progress.insert("lidas", lidas);
    commit();
}

bool Backend::isRead(const QString &id) const { return section("lidas").contains(id); }

int Backend::readCount() const {
    int count = 0;
    for (const auto &id : m_lessonOrder)
        count += isRead(id);
    return count;
}

int Backend::chapterRead(const QString &chapterId) const {
    int count = 0;
    for (const auto &id : m_lessonOrder)
        count += m_lessonChapter.value(id).id == chapterId && isRead(id);
    return count;
}

// --- Quiz -------------------------------------------------------------------

QVariantList Backend::quiz(const QString &chapterId) const {
    if (!chapterId.isEmpty())
        return m_quizzes.value(chapterId).toVariantList();
    // The mixed quiz draws from every chapter.
    QVariantList all;
    for (const auto &quizValue : m_quizJson)
        for (const auto &question : quizValue.toObject().value("perguntas").toArray())
            all << question.toObject().toVariantMap();
    return all;
}

void Backend::recordQuiz(const QString &chapterId, int score, int total) {
    const QString key = chapterId.isEmpty() ? QString("geral") : chapterId;
    auto quizzes = section("quiz");
    auto stats = quizzes.value(key).toObject();
    stats.insert("tentativas", stats.value("tentativas").toInt() + 1);
    stats.insert("ultima", score);
    stats.insert("total", total);
    stats.insert("data", m_today.toString(Qt::ISODate));
    if (!stats.contains("melhor") || score > stats.value("melhor").toInt())
        stats.insert("melhor", score);
    quizzes.insert(key, stats);
    m_progress.insert("quiz", quizzes);
    commit();
}

QVariantMap Backend::quizStats(const QString &chapterId) const {
    return section("quiz").value(chapterId.isEmpty() ? QString("geral") : chapterId).toObject().toVariantMap();
}

int Backend::questionsTotal() const {
    int count = 0;
    for (const auto &questions : m_quizzes)
        count += questions.size();
    return count;
}

// --- Flashcards -------------------------------------------------------------

bool Backend::cardDue(const QString &term) const {
    const auto card = section("cards").value(term).toObject();
    if (card.isEmpty())
        return true;
    const QDate next = QDate::fromString(card.value("proxima").toString(), Qt::ISODate);
    return !next.isValid() || next <= m_today;
}

QVariantMap Backend::termMap(const QString &term) const {
    auto map = m_terms.value(term);
    map.insert("caixa", cardBox(term));
    return map;
}

QVariantList Backend::dueCards(int limit) const {
    // Cards already in review come first, weakest box first; new cards fill
    // the rest of the session in random order so the alphabet doesn't decide.
    QList<QPair<int, QString>> review;
    QStringList fresh;
    for (const auto &value : m_glossary) {
        const QString term = value.toMap().value("termo").toString();
        if (!cardDue(term))
            continue;
        const int box = cardBox(term);
        if (box == 0)
            fresh << term;
        else
            review << qMakePair(box, term);
    }
    std::stable_sort(review.begin(), review.end(), [](auto a, auto b) { return a.first < b.first; });
    std::shuffle(fresh.begin(), fresh.end(), *QRandomGenerator::global());
    QVariantList cards;
    for (const auto &pair : review)
        if (cards.size() < limit)
            cards << termMap(pair.second);
    for (const auto &term : fresh)
        if (cards.size() < limit)
            cards << termMap(term);
    return cards;
}

QVariantList Backend::randomCards(int limit) const {
    QStringList terms = m_terms.keys();
    std::shuffle(terms.begin(), terms.end(), *QRandomGenerator::global());
    QVariantList cards;
    for (const auto &term : terms.mid(0, limit))
        cards << termMap(term);
    return cards;
}

int Backend::dueCount() const {
    int count = 0;
    for (auto it = m_terms.cbegin(); it != m_terms.cend(); ++it)
        count += cardDue(it.key());
    return count;
}

QVariantList Backend::boxCounts() const {
    QVariantList counts{0, 0, 0, 0, 0, 0};
    for (auto it = m_terms.cbegin(); it != m_terms.cend(); ++it) {
        const int box = cardBox(it.key());
        counts[box] = counts[box].toInt() + 1;
    }
    return counts;
}

void Backend::answerCard(const QString &term, bool knew) {
    if (!m_terms.contains(term))
        return;
    auto cards = section("cards");
    auto card = cards.value(term).toObject();
    const int box = knew ? std::min(cardBox(term) + 1, 5) : 1;
    card.insert("caixa", box);
    card.insert("proxima", m_today.addDays(intervalDays(box)).toString(Qt::ISODate));
    card.insert(knew ? "acertos" : "erros", card.value(knew ? "acertos" : "erros").toInt() + 1);
    cards.insert(term, card);
    m_progress.insert("cards", cards);
    commit();
}

int Backend::cardBox(const QString &term) const {
    return std::clamp(section("cards").value(term).toObject().value("caixa").toInt(), 0, 5);
}

// --- Search and text --------------------------------------------------------

QVariantList Backend::search(const QString &query) const {
    const QString q = normalize(query).simplified();
    if (q.size() < 2)
        return {};
    QList<QPair<int, QVariantMap>> hits;
    for (const auto &value : m_glossary) {
        const auto term = value.toMap();
        const QString name = normalize(term.value("termo").toString());
        const QString full = normalize(term.value("nome").toString());
        int score = name == q ? 120 : name.startsWith(q) ? 100 : name.contains(q) || full.contains(q) ? 80
                  : term.value("busca").toString().contains(q) ? 30 : 0;
        if (score)
            hits << qMakePair(score, QVariantMap{{"tipo", "termo"},
                                                 {"titulo", term.value("termo")},
                                                 {"contexto", plain(term.value("definicao").toString())},
                                                 {"alvo", term.value("termo")}});
    }
    for (const auto &id : m_lessonOrder) {
        const QString title = m_lessons.value(id).value("titulo").toString();
        const QString text = m_lessonText.value(id);
        const bool inTitle = normalize(title).contains(q);
        const bool inText = normalize(text).contains(q);
        if (!inTitle && !inText)
            continue;
        const auto chapter = m_lessonChapter.value(id);
        hits << qMakePair(inTitle ? 90 : 20,
                          QVariantMap{{"tipo", "licao"},
                                      {"titulo", title},
                                      {"contexto", inText ? excerpt(text, q)
                                                          : QString("Capítulo %1 · %2").arg(chapter.number).arg(chapter.title)},
                                      {"alvo", id}});
    }
    for (const auto &id : m_itemIds) {
        const QString text = m_itemText.value(id).trimmed();
        if (normalize(text).contains(q))
            hits << qMakePair(40, QVariantMap{{"tipo", "item"},
                                              {"titulo", text},
                                              {"contexto", "Trilha · " + m_phaseTitle.value(m_itemPhase.value(id))},
                                              {"alvo", m_itemPhase.value(id)}});
    }
    std::stable_sort(hits.begin(), hits.end(), [](const auto &a, const auto &b) { return a.first > b.first; });
    QVariantList results;
    for (const auto &hit : hits.mid(0, 40))
        results << hit.second;
    return results;
}

// Turns the content's tiny markup (**bold**, *italic*, `code`) into the HTML
// subset Qt's rich text understands.
QString Backend::rich(const QString &text, const QString &codeColor) const {
    static const QRegularExpression code(R"(`([^`]+)`)");
    static const QRegularExpression bold(R"(\*\*(.+?)\*\*)");
    static const QRegularExpression italic(R"((?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*]))");
    // Code spans are swapped for placeholders first, so an asterisk inside
    // `/opt/app_*` never starts italics, while **bold** may still wrap code.
    QStringList spans;
    QString out = escapeHtml(text);
    QString swapped;
    int last = 0;
    for (auto it = code.globalMatch(out); it.hasNext();) {
        const auto match = it.next();
        swapped += out.mid(last, match.capturedStart() - last) + QString("\x01%1\x02").arg(spans.size());
        spans << match.captured(1);
        last = match.capturedEnd();
    }
    out = swapped + out.mid(last);
    out.replace(bold, "<b>\\1</b>");
    out.replace(italic, "<i>\\1</i>");
    for (int i = 0; i < spans.size(); ++i)
        out.replace(QString("\x01%1\x02").arg(i),
                    QString("<font face=\"%1\" color=\"%2\">%3</font>").arg(m_mono, codeColor, spans.at(i)));
    out.replace('\n', "<br>");
    return out;
}

// Shell-style code with `# comments` dimmed, spaces kept as typed.
QString Backend::codeHtml(const QString &text, const QString &commentColor) const {
    QStringList lines;
    for (const QString &line : text.split('\n')) {
        int comment = -1;
        for (int i = 0; i < line.size(); ++i)
            if (line.at(i) == '#' && (i == 0 || line.at(i - 1).isSpace())) {
                comment = i;
                break;
            }
        auto keep = [](QString s) { return escapeHtml(s).replace(' ', "&nbsp;"); };
        QString html = keep(comment < 0 ? line : line.left(comment));
        if (comment >= 0)
            html += QString("<font color=\"%1\">%2</font>").arg(commentColor, keep(line.mid(comment)));
        lines << html;
    }
    return lines.join("<br>");
}

void Backend::copy(const QString &text) const {
    if (auto *app = qobject_cast<QGuiApplication *>(QCoreApplication::instance()))
        app->clipboard()->setText(text);
}

// --- Validation and summary -------------------------------------------------

QStringList Backend::validate() const {
    QStringList problems = m_loadErrors;
    QSet<QString> chapterIds;
    for (const auto &chapter : m_chapters)
        chapterIds << chapter.toMap().value("id").toString();
    auto lessonExists = [this](const QString &id) { return m_lessons.contains(id); };

    QSet<QString> seen;
    for (const auto &phaseValue : m_phasesJson) {
        const auto phase = phaseValue.toObject();
        if (!chapterIds.contains(phase.value("capitulo").toString()))
            problems << QString("Fase %1 aponta para o capítulo inexistente %2")
                            .arg(phase.value("id").toString(), phase.value("capitulo").toString());
        for (const auto &itemValue : phase.value("itens").toArray()) {
            const auto item = itemValue.toObject();
            const QString id = item.value("id").toString();
            if (seen.contains(id))
                problems << QString("Item da trilha repetido: %1").arg(id);
            seen << id;
            if (!QStringList{"estudo", "lab", "real"}.contains(item.value("tipo").toString()))
                problems << QString("Item %1 com tipo desconhecido").arg(id);
        }
    }

    seen.clear();
    static const QStringList blockTypes{"p", "lista", "codigo", "tabela", "aviso"};
    for (const auto &id : m_lessonOrder) {
        if (seen.contains(id))
            problems << QString("Lição repetida: %1").arg(id);
        seen << id;
        for (const auto &blockValue : m_lessons.value(id).value("blocos").toArray()) {
            const auto block = blockValue.toObject();
            const QString type = block.value("tipo").toString();
            if (!blockTypes.contains(type))
                problems << QString("Lição %1 tem bloco de tipo desconhecido: %2").arg(id, type);
            if (type == "tabela") {
                const int columns = block.value("colunas").toArray().size();
                for (const auto &row : block.value("linhas").toArray())
                    if (row.toArray().size() != columns)
                        problems << QString("Tabela da lição %1 tem linha com número errado de colunas").arg(id);
            }
        }
    }

    seen.clear();
    for (const auto &value : m_glossaryJson) {
        const auto term = value.toObject();
        const QString name = term.value("termo").toString();
        if (name.isEmpty() || term.value("definicao").toString().isEmpty())
            problems << QString("Termo do glossário sem nome ou definição: %1").arg(name);
        if (seen.contains(name))
            problems << QString("Termo repetido no glossário: %1").arg(name);
        seen << name;
        if (!lessonExists(term.value("licao").toString()))
            problems << QString("Termo %1 aponta para a lição inexistente %2").arg(name, term.value("licao").toString());
    }

    seen.clear();
    for (const auto &quizValue : m_quizJson) {
        const auto quiz = quizValue.toObject();
        if (!chapterIds.contains(quiz.value("capitulo").toString()))
            problems << QString("Quiz do capítulo inexistente %1").arg(quiz.value("capitulo").toString());
        for (const auto &questionValue : quiz.value("perguntas").toArray()) {
            const auto question = questionValue.toObject();
            const QString id = question.value("id").toString();
            if (seen.contains(id))
                problems << QString("Pergunta repetida: %1").arg(id);
            seen << id;
            const int options = question.value("opcoes").toArray().size();
            const int correct = question.value("correta").toInt(-1);
            if (options != 4)
                problems << QString("Pergunta %1 tem %2 opções em vez de 4").arg(id).arg(options);
            if (correct < 0 || correct >= options)
                problems << QString("Pergunta %1 tem resposta correta fora das opções").arg(id);
            if (!lessonExists(question.value("licao").toString()))
                problems << QString("Pergunta %1 aponta para a lição inexistente %2").arg(id, question.value("licao").toString());
        }
    }
    return problems;
}

QJsonObject Backend::summary() const {
    QJsonObject quiz;
    for (const auto &chapter : m_chapters) {
        const QString id = chapter.toMap().value("id").toString();
        if (const auto stats = quizStats(id); !stats.isEmpty())
            quiz.insert(id, QJsonObject::fromVariantMap(stats));
    }
    if (const auto stats = quizStats({}); !stats.isEmpty())
        quiz.insert("geral", QJsonObject::fromVariantMap(stats));
    QJsonArray boxes;
    for (const auto &count : boxCounts())
        boxes << count.toInt();
    return {{"trilha", QJsonObject{{"feitos", itemsDone()}, {"total", itemsTotal()},
                                   {"itens", section("trilha")}}},
            {"licoes", QJsonObject{{"lidas", readCount()}, {"total", lessonsTotal()},
                                   {"ultima", lastLesson()}}},
            {"flashcards", QJsonObject{{"paraHoje", dueCount()}, {"caixas", boxes}}},
            {"quiz", quiz},
            {"arquivo", m_progressPath},
            {"conteudoProprio", QJsonArray::fromStringList(m_overridden)}};
}
