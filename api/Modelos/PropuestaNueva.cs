namespace GestorTrabajoApi.Modelos;

// Se valida en fn_enviar_oferta, que responde con mensajes en español.
public class PropuestaNueva
{
    public decimal? Precio { get; set; }
    public string? Mensaje { get; set; }
}
