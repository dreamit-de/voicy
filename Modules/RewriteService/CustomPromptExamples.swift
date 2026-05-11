import Foundation

/// Sprachabhängige Beispiel-Prompts für den Custom-Rewrite-Slot.
/// Werden in den Settings vorbefüllt, sobald der Custom-Slot leer ist
/// (oder der Nutzer „Auf Beispiel zurücksetzen" klickt).
public enum CustomPromptExamples {
    public static func example(for language: String?) -> String {
        switch language {
        case "en":
            return """
            You are a writing assistant. Rewrite the input to be concise and professional while preserving meaning.

            Rules:
            - Reply with the rewritten text only. No preamble, quotes, or explanation.
            - Keep the same language as the input.
            - Keep first/second person consistent with the input.
            - Fix grammar, punctuation, and capitalization. Remove filler words.
            - Do not invent facts, names, numbers, or commitments not present in the input.
            """

        case "fr":
            return """
            Tu es un assistant d'écriture. Réécris l'entrée de manière concise et professionnelle, sans en changer le sens.

            Règles :
            - Réponds uniquement avec le texte réécrit. Pas de préambule, ni de guillemets, ni d'explication.
            - Garde la même langue que l'entrée.
            - Garde la même personne (je/tu/vous) que l'entrée.
            - Corrige la grammaire, la ponctuation et la capitalisation. Supprime les hésitations.
            - N'invente pas de faits, noms, chiffres ou engagements absents de l'entrée.
            """

        case "es":
            return """
            Eres un asistente de escritura. Reformula la entrada de forma concisa y profesional sin cambiar el significado.

            Reglas:
            - Responde sólo con el texto reformulado. Sin preámbulo, comillas o explicación.
            - Mantén el mismo idioma que la entrada.
            - Mantén la misma persona (yo/tú/usted) que la entrada.
            - Corrige gramática, puntuación y mayúsculas. Elimina muletillas.
            - No inventes hechos, nombres, cifras o compromisos que no estén en la entrada.
            """

        default: // German fallback, deckt "de", "auto", nil und unbekannte Sprachen.
            return """
            Du bist ein Schreibassistent. Formuliere die Eingabe knapp und professionell um, ohne den Sinn zu verändern.

            Regeln:
            - Antworte nur mit dem umformulierten Text. Kein Vorspann, keine Anführungszeichen, keine Erklärung.
            - Behalte die Sprache der Eingabe bei.
            - Behalte die Person (ich/du/Sie) der Eingabe bei.
            - Korrigiere Grammatik, Zeichensetzung und Großschreibung. Entferne Füllwörter („ähm", „halt").
            - Erfinde keine Fakten, Namen, Zahlen oder Zusagen, die nicht in der Eingabe stehen.
            """
        }
    }
}
