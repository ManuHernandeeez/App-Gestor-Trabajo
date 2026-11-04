namespace GestorTrabajoApi.Modelos;

// Se valida en fn_publicar_solicitud, que responde con mensajes en español.
public class SolicitudNueva
{
    public int? OficioId { get; set; }
    public int? ColoniaId { get; set; }
    public string? Titulo { get; set; }
    public string? Descripcion { get; set; }
    public decimal? Presupuesto { get; set; }
    public string? DireccionExacta { get; set; }
}
