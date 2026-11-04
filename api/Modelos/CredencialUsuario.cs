namespace GestorTrabajoApi.Modelos;

// Lo que se lee del usuario para iniciar sesión. No sale nunca en una respuesta.
public record CredencialUsuario(int Id, string Rol, string Nombre, string PasswordHash, string Estado);
