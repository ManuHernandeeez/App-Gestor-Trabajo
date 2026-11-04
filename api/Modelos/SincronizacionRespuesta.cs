namespace GestorTrabajoApi.Modelos;

// Lo nuevo para el usuario desde la última carga. Ahora es la hora del servidor al preguntar:
// la app la guarda y la manda como "desde" la próxima vez.
public record SincronizacionRespuesta(DateTimeOffset Ahora, List<MensajeSincronizadoRespuesta> Mensajes, List<AvisoRespuesta> Avisos);

public record MensajeSincronizadoRespuesta(
    int Id, int SolicitudId, string Titulo, string EmisorNombre, string Texto, DateTimeOffset Fecha);

// Tipo es por ejemplo propuesta_nueva, propuesta_aceptada, mensaje_nuevo. Solicitud y Titulo vienen de la solicitud del aviso.
public record AvisoRespuesta(int Id, int? SolicitudId, string? Titulo, string Tipo, string Texto, DateTimeOffset Fecha, bool Leido);
