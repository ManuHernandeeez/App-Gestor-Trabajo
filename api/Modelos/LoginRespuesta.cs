namespace GestorTrabajoApi.Modelos;

public record LoginRespuesta(string Token, string Rol, int UsuarioId, string Nombre);
