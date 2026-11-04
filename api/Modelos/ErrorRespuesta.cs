namespace GestorTrabajoApi.Modelos;

// Cuerpo de todos los errores de la API: GT001, GT002 y GT003 vienen de la base; el resto los pone la API.
public record ErrorRespuesta(string Codigo, string Mensaje);
