namespace GestorTrabajoApi.Modelos;

// Se valida en fn_enviar_mensaje, que responde con mensajes en español.
// OtraParteId es el trabajador con quien habla el cliente; es opcional si el trabajo ya tiene trabajador
// asignado y el trabajador no necesita indicarlo.
public class MensajeNuevo
{
    public string? Texto { get; set; }
    public int? OtraParteId { get; set; }
}
