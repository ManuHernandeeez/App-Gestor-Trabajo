namespace GestorTrabajoApi.Modelos;

// Un trabajo con trabajador asignado, visto desde una de sus dos partes.
// UltimoMensaje y FechaUltimo son null si todavía no hay mensajes. MensajesNuevos cuenta los avisos de mensaje sin leer.
public record ConversacionRespuesta(
    int SolicitudId,
    string Titulo,
    string Estado,
    string OtraParteNombre,
    string? UltimoMensaje,
    DateTimeOffset? FechaUltimo,
    int MensajesNuevos);
