namespace GestorTrabajoApi.Modelos;

// Una propuesta en la lista del trabajador que la envió. Presupuesto es el de la solicitud y Precio el ofrecido.
public record PropuestaPropiaRespuesta(
    int Id,
    int SolicitudId,
    string Titulo,
    string Oficio,
    string Zona,
    string ClienteNombre,
    decimal Presupuesto,
    decimal Precio,
    string? Mensaje,
    string Estado,
    string EstadoSolicitud,
    DateTimeOffset Fecha);
