namespace GestorTrabajoApi.Modelos;

// Qué avisos marcar como leídos: los de una solicitud, los de una lista o, si no se indica nada, todos.
// Una lista vacía no marca ninguno.
public class AvisosLeidosEdicion
{
    public List<int>? Ids { get; set; }
    public int? SolicitudId { get; set; }
}

public record AvisosLeidosRespuesta(int Marcados);
