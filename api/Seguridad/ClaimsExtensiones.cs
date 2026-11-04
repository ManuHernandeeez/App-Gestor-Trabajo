using System.Security.Claims;

namespace GestorTrabajoApi.Seguridad;

public static class ClaimsExtensiones
{
    // Id del usuario del token (claim sub). Solo se usa en acciones con [Authorize].
    public static int ObtenerUsuarioId(this ClaimsPrincipal usuario)
    {
        return int.Parse(usuario.FindFirstValue("sub")!);
    }
}
