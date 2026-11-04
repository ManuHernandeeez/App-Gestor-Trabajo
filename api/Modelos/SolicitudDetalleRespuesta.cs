namespace GestorTrabajoApi.Modelos;

// Detalle de una solicitud, sin dirección ni datos de contacto.
// Para el dueño: ClienteNombre completo y Propuestas con el conteo; MiPropuesta es null.
// Para un trabajador: ClienteNombre abreviado, Propuestas null y MiPropuesta con la suya (o null si no envió).
// TrabajadorNombre solo lo reciben el dueño y el trabajador asignado.
// YaCalifique es true si quien consulta ya calificó este trabajo.
public record SolicitudDetalleRespuesta(
    int Id,
    string Titulo,
    string Descripcion,
    string Oficio,
    string Zona,
    decimal Presupuesto,
    string Estado,
    DateTimeOffset FechaPublicacion,
    int ClienteId,
    string ClienteNombre,
    string? TrabajadorNombre,
    int? Propuestas,
    MiPropuestaRespuesta? MiPropuesta,
    bool YaCalifique = false);

public record MiPropuestaRespuesta(int Id, decimal Precio, string Estado);
