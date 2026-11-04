using System.ComponentModel.DataAnnotations;

namespace GestorTrabajoApi.Modelos;

// Casi todo se valida en fn_registrar_usuario, que responde con mensajes en español.
// Aquí solo se revisa la contraseña, porque la base nunca la ve en texto plano.
public class RegistroSolicitud
{
    public string? Rol { get; set; }
    public string? Nombre { get; set; }
    public string? Correo { get; set; }

    [Required(ErrorMessage = "La contraseña es obligatoria")]
    [MinLength(8, ErrorMessage = "La contraseña debe tener al menos 8 caracteres")]
    [MaxLength(72, ErrorMessage = "La contraseña no puede pasar de 72 caracteres")]
    public string? Password { get; set; }

    public string? Telefono { get; set; }
    public string? Dui { get; set; }
    public int? MunicipioId { get; set; }
    public int? ColoniaId { get; set; }
    public int[]? Oficios { get; set; }
    public int[]? Colonias { get; set; }
}
