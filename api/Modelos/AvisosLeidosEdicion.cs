namespace GestorTrabajoApi.Modelos;

// Qué avisos marcar como leídos: los de una solicitud, los de una lista o, si no se indica nada, todos.
// Una lista vacía no marca ninguno. Con SolicitudId y OtraParteId solo se marcan los avisos de mensaje de ese hilo del chat.
public class AvisosLeidosEdicion
{
    public List<int>? Ids { get; set; }
    public int? SolicitudId { get; set; }
    public int? OtraParteId { get; set; }
}

public record AvisosLeidosRespuesta(int Marcados);
