using System.Security.Claims;
using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using Microsoft.AspNetCore.Authentication.JwtBearer;

namespace GestorTrabajoApi.Seguridad;

// Comprueba en cada petición que la cuenta siga activa (un suspendido pierde el acceso al instante)
// y responde los 401 y 403 con el mismo cuerpo de error que el resto de la API.
public static class EventosJwt
{
    public static JwtBearerEvents Crear()
    {
        return new JwtBearerEvents
        {
            OnTokenValidated = ComprobarCuentaActivaAsync,
            OnChallenge = ResponderNoAutenticadoAsync,
            OnForbidden = ResponderSinPermisoAsync
        };
    }

    private static async Task ComprobarCuentaActivaAsync(TokenValidatedContext contexto)
    {
        if (!int.TryParse(contexto.Principal?.FindFirstValue("sub"), out var usuarioId))
        {
            contexto.Fail("El token no trae el usuario");
            return;
        }

        var usuarios = contexto.HttpContext.RequestServices.GetRequiredService<UsuarioRepositorio>();
        var estado = await usuarios.ObtenerEstadoAsync(usuarioId);
        if (estado != "activo")
        {
            contexto.Fail("La cuenta no está activa");
        }
    }

    private static async Task ResponderNoAutenticadoAsync(JwtBearerChallengeContext contexto)
    {
        contexto.HandleResponse();
        contexto.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await contexto.Response.WriteAsJsonAsync(new ErrorRespuesta(
            "NO_AUTENTICADO", "Tu sesión no es válida, venció o tu cuenta fue suspendida. Inicia sesión de nuevo"));
    }

    private static async Task ResponderSinPermisoAsync(ForbiddenContext contexto)
    {
        contexto.Response.StatusCode = StatusCodes.Status403Forbidden;
        await contexto.Response.WriteAsJsonAsync(new ErrorRespuesta("GT003", "No tienes permiso para esta acción"));
    }
}
