namespace GestorTrabajoApi.Modelos;

// Valores permitidos para filtrar listas por estado.
public static class Estados
{
    private static readonly string[] Solicitud = { "publicada", "asignada", "en_proceso", "finalizada", "cancelada", "vencida" };
    private static readonly string[] Propuesta = { "pendiente", "aceptada", "rechazada", "retirada" };

    public static bool EsSolicitudValido(string estado)
    {
        return Array.IndexOf(Solicitud, estado) >= 0;
    }

    public static bool EsPropuestaValido(string estado)
    {
        return Array.IndexOf(Propuesta, estado) >= 0;
    }
}
