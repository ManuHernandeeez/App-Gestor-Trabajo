namespace GestorTrabajoApi.Modelos;

// Una propuesta vista por el dueño de la solicitud.
public record PropuestaDeSolicitudRespuesta(
    int Id,
    int TrabajadorId,
    string TrabajadorNombre,
    decimal PromedioCalificacion,
    int TotalCalificaciones,
    decimal Precio,
    string? Mensaje,
    string Estado,
    DateTimeOffset Fecha);
