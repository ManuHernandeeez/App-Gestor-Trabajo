namespace GestorTrabajoApi.Modelos;

// Lo que no se envía se queda como estaba. El padre de un municipio o colonia no cambia.
public class CatalogoEdicion
{
    public string? Nombre { get; set; }
    public bool? Activo { get; set; }
}
