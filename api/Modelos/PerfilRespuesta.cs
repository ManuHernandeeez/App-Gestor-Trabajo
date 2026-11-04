namespace GestorTrabajoApi.Modelos;

// Perfil propio. El DUI va enmascarado; correo y dirección no se incluyen.
// El cliente trae Colonia; el trabajador trae Oficios y ColoniasTrabajo.
// FotoUrl es relativa a la URL base de la API (por ejemplo "fotos/abc.jpg").
public record PerfilRespuesta(
    int Id,
    string Rol,
    string Nombre,
    string? Telefono,
    string? DuiEnmascarado,
    string? FotoUrl,
    decimal PromedioCalificacion,
    int TotalCalificaciones,
    ElementoCatalogo? Departamento,
    ElementoCatalogo? Municipio,
    ElementoCatalogo? Colonia,
    List<ElementoCatalogo> Oficios,
    List<ElementoCatalogo> ColoniasTrabajo);
