namespace GestorTrabajoApi.Modelos;

// Datos de contacto e identidad de un usuario, solo para el administrador.
// Telefono, Dui y Zona son null cuando el usuario no los tiene (el DUI es solo de trabajadores).
public record AuditoriaRespuesta(
    int Id,
    string Rol,
    string Nombre,
    string Correo,
    string? Telefono,
    string? Dui,
    string Estado,
    DateTimeOffset FechaRegistro,
    string? Zona);
