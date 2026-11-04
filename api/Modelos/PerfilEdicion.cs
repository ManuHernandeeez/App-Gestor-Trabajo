namespace GestorTrabajoApi.Modelos;

// Se valida en fn_actualizar_perfil, que responde con mensajes en español.
// ColoniaId solo lo lleva el cliente.
public class PerfilEdicion
{
    public string? Nombre { get; set; }
    public string? Telefono { get; set; }
    public int? MunicipioId { get; set; }
    public int? ColoniaId { get; set; }
}
