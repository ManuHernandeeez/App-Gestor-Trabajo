using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GestorTrabajoApi.Controllers;

// Propuestas: el trabajador las envía y retira, el cliente las acepta o rechaza.
// Las reglas (dueño, estados, zona y oficios) las aplica la base; aquí solo se separan los roles.
[ApiController]
[Route("api")]
public class OfertasController : ControllerBase
{
    private readonly PropuestaRepositorio _propuestas;

    public OfertasController(PropuestaRepositorio propuestas)
    {
        _propuestas = propuestas;
    }

    // Cliente

    [HttpPost("propuestas/{id:int}/aceptar")]
    [Authorize(Roles = "cliente")]
    public async Task<IActionResult> Aceptar(int id)
    {
        await _propuestas.AceptarAsync(User.ObtenerUsuarioId(), id);
        return NoContent();
    }

    [HttpPost("propuestas/{id:int}/rechazar")]
    [Authorize(Roles = "cliente")]
    public async Task<IActionResult> Rechazar(int id)
    {
        await _propuestas.RechazarAsync(User.ObtenerUsuarioId(), id);
        return NoContent();
    }

    // Trabajador

    [HttpGet("trabajos/zona")]
    [Authorize(Roles = "trabajador")]
    public Task<List<TrabajoZonaRespuesta>> TrabajosDeLaZona([FromQuery] int? oficioId)
    {
        return _propuestas.ListarZonaAsync(User.ObtenerUsuarioId(), oficioId);
    }

    [HttpPost("trabajos/{solicitudId:int}/propuestas")]
    [Authorize(Roles = "trabajador")]
    public async Task<ActionResult<PropuestaCreadaRespuesta>> Enviar(int solicitudId, PropuestaNueva propuesta)
    {
        var id = await _propuestas.EnviarAsync(User.ObtenerUsuarioId(), solicitudId, propuesta);
        return StatusCode(StatusCodes.Status201Created, new PropuestaCreadaRespuesta(id));
    }

    [HttpGet("propuestas/mias")]
    [Authorize(Roles = "trabajador")]
    public async Task<ActionResult<List<PropuestaPropiaRespuesta>>> Mias([FromQuery] string? estado)
    {
        if (!string.IsNullOrEmpty(estado) && !Estados.EsPropuestaValido(estado))
        {
            return BadRequest(new ErrorRespuesta("SOLICITUD_INVALIDA", "El estado indicado no es válido"));
        }
        return await _propuestas.ListarDeTrabajadorAsync(User.ObtenerUsuarioId(), string.IsNullOrEmpty(estado) ? null : estado);
    }

    [HttpPut("propuestas/{id:int}/retirar")]
    [Authorize(Roles = "trabajador")]
    public async Task<IActionResult> Retirar(int id)
    {
        await _propuestas.RetirarAsync(User.ObtenerUsuarioId(), id);
        return NoContent();
    }
}
