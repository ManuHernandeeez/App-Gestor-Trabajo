namespace GestorTrabajoApi.Modelos;

// Un mensaje de un trabajo. EsMio indica si lo escribió quien consulta.
public record MensajeRespuesta(int Id, int EmisorId, string EmisorNombre, string Texto, DateTimeOffset Fecha, bool EsMio);
