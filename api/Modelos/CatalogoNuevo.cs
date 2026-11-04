namespace GestorTrabajoApi.Modelos;

// Datos para crear un elemento de catálogo. Un municipio lleva DepartamentoId y una colonia MunicipioId.
// Activo es true si no se indica. Se valida en las funciones fn_guardar_..., que responden en español.
public class CatalogoNuevo
{
    public string? Nombre { get; set; }
    public bool? Activo { get; set; }
    public int? DepartamentoId { get; set; }
    public int? MunicipioId { get; set; }
}
