namespace GestorTrabajoApi.Modelos;

// Una solicitud en la lista del cliente. Propuestas cuenta las que no fueron retiradas.
// No lleva la dirección exacta.
public record SolicitudResumenRespuesta(
    int Id,
    string Titulo,
    string Oficio,
    string Zona,
    decimal Presupuesto,
    string Estado,
    DateTimeOffset FechaPublicacion,
    int Propuestas);
