namespace GestorTrabajoApi.Modelos;

// Promedio y últimas calificaciones recibidas. Los nombres salen abreviados.
public record ReputacionRespuesta(
    string Nombre,
    decimal Promedio,
    int Total,
    List<CalificacionRecibidaRespuesta> Ultimas);

public record CalificacionRecibidaRespuesta(int Estrellas, string Comentario, string CalificadorNombre, DateTimeOffset Fecha);
