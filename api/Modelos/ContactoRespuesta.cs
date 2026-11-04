namespace GestorTrabajoApi.Modelos;

// Nombre y teléfono de la otra parte y dirección exacta del trabajo.
// Solo se entrega al cliente dueño y al trabajador asignado, con el trabajo asignado o más adelante.
public record ContactoRespuesta(string Rol, string Nombre, string? Telefono, string? DireccionExacta);
