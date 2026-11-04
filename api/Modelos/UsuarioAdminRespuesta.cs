namespace GestorTrabajoApi.Modelos;

// Un usuario en la búsqueda del administrador. Sin correo, teléfono ni DUI: esos salen solo en la auditoría.
public record UsuarioAdminRespuesta(
    int Id,
    string Rol,
    string Nombre,
    string Estado,
    decimal PromedioCalificacion,
    int TotalCalificaciones,
    DateTimeOffset FechaRegistro);
