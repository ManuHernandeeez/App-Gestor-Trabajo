using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GestorTrabajoApi.Controllers;

// Perfil del usuario con sesión. Siempre es el del token: no se recibe un id por la ruta.
[ApiController]
[Route("api/perfil")]
[Authorize(Roles = "cliente,trabajador")]
public class UsuariosController : ControllerBase
{
    private readonly PerfilRepositorio _perfiles;

    public UsuariosController(PerfilRepositorio perfiles)
    {
        _perfiles = perfiles;
    }

    [HttpGet]
    public async Task<ActionResult<PerfilRespuesta>> ObtenerPerfil()
    {
        var perfil = await _perfiles.ObtenerAsync(User.ObtenerUsuarioId());
        if (perfil == null)
        {
            return NotFound(new ErrorRespuesta("GT002", "No se encontró el perfil"));
        }
        return perfil;
    }

    [HttpPut]
    public async Task<IActionResult> Actualizar(PerfilEdicion datos)
    {
        await _perfiles.ActualizarAsync(User.ObtenerUsuarioId(), datos);
        return NoContent();
    }

    [HttpPut("oficios")]
    [Authorize(Roles = "trabajador")]
    public async Task<IActionResult> ReemplazarOficios(OficiosEdicion datos)
    {
        await _perfiles.ReemplazarOficiosAsync(User.ObtenerUsuarioId(), datos);
        return NoContent();
    }

    [HttpPut("colonias")]
    [Authorize(Roles = "trabajador")]
    public async Task<IActionResult> ReemplazarColonias(ColoniasEdicion datos)
    {
        await _perfiles.ReemplazarColoniasAsync(User.ObtenerUsuarioId(), datos);
        return NoContent();
    }
}
