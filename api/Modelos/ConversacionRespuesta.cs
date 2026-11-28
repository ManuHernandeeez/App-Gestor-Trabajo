namespace GestorTrabajoApi.Modelos;

// Un hilo de chat, visto desde una de sus dos partes: el cliente y un trabajador que envió propuesta a la solicitud.
// UltimoMensaje y FechaUltimo son null si todavía no hay mensajes. MensajesNuevos cuenta los avisos de mensaje
// sin leer de ese hilo. PuedeEscribir es false cuando el hilo quedó de solo lectura (propuesta rechazada o retirada,
// solicitud cancelada o vencida).
public record ConversacionRespuesta(
    int SolicitudId,
    string Titulo,
    string Estado,
    int OtraParteId,
    string OtraParteNombre,
    string? UltimoMensaje,
    DateTimeOffset? FechaUltimo,
    int MensajesNuevos,
    bool PuedeEscribir);
