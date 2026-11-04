namespace GestorTrabajoApi.Modelos;

// Un trabajo de la zona del trabajador. Sin teléfono ni dirección, y con el nombre del cliente abreviado.
public record TrabajoZonaRespuesta(
    int Id,
    string Titulo,
    string Oficio,
    decimal Presupuesto,
    string Zona,
    string ClienteNombre,
    int PublicadaHaceHoras,
    bool YaPropuse);
