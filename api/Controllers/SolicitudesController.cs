using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GestorTrabajoApi.Controllers;

// Lo que hace el cliente con sus solicitudes, y el detalle que ven cliente y trabajador.
// Siempre trabaja con el usuario del token. El rol se fija en cada acción.
[ApiController]
[Route("api/solicitudes")]
[Authorize]
public class SolicitudesController : ControllerBase
{
    private readonly SolicitudRepositorio _solicitudes;
    private readonly PropuestaRepositorio _propuestas;

    public SolicitudesController(SolicitudRepositorio solicitudes, PropuestaRepositorio propuestas)
    {
        _solicitudes = solicitudes;
        _propuestas = propuestas;
    }

    [HttpPost]
    [Authorize(Roles = "cliente")]
    public async Task<ActionResult<SolicitudCreadaRespuesta>> Publicar(SolicitudNueva solicitud)
    {
        var id = await _solicitudes.PublicarAsync(User.ObtenerUsuarioId(), solicitud);
        return StatusCode(StatusCodes.Status201Created, new SolicitudCreadaRespuesta(id));
    }

    [HttpGet("mias")]
    [Authorize(Roles = "cliente")]
    public async Task<ActionResult<List<SolicitudResumenRespuesta>>> Mias([FromQuery] string? estado)
    {
        if (!string.IsNullOrEmpty(estado) && !Estados.EsSolicitudValido(estado))
        {
            return BadRequest(new ErrorRespuesta("SOLICITUD_INVALIDA", "El estado indicado no es válido"));
        }
        return await _solicitudes.ListarDeClienteAsync(User.ObtenerUsuarioId(), string.IsNullOrEmpty(estado) ? null : estado);
    }

    [HttpGet("{id:int}")]
    [Authorize(Roles = "cliente,trabajador")]
    public async Task<ActionResult<SolicitudDetalleRespuesta>> Detalle(int id)
    {
        var detalle = await _solicitudes.ObtenerDetalleAsync(User.ObtenerUsuarioId(), id);
        if (detalle == null)
        {
            return NotFound(new ErrorRespuesta("GT002", "La solicitud no existe"));
        }
        return detalle;
    }

    [HttpGet("{id:int}/propuestas")]
    [Authorize(Roles = "cliente")]
    public Task<List<PropuestaDeSolicitudRespuesta>> Propuestas(int id)
    {
        return _propuestas.ListarDeSolicitudAsync(User.ObtenerUsuarioId(), id);
    }

    [HttpPut("{id:int}/cancelar")]
    [Authorize(Roles = "cliente")]
    public async Task<IActionResult> Cancelar(int id)
    {
        await _solicitudes.CancelarAsync(User.ObtenerUsuarioId(), id);
        return NoContent();
    }

    // El cliente confirma que el trabajo terminó
    [HttpPut("{id:int}/finalizar")]
    [Authorize(Roles = "cliente")]
    public async Task<IActionResult> Finalizar(int id)
    {
        await _solicitudes.FinalizarAsync(User.ObtenerUsuarioId(), id);
        return NoContent();
    }

    // El trabajador asignado avisa que empezó
    [HttpPut("~/api/trabajos/{solicitudId:int}/en-proceso")]
    [Authorize(Roles = "trabajador")]
    public async Task<IActionResult> MarcarEnProceso(int solicitudId)
    {
        await _solicitudes.MarcarEnProcesoAsync(User.ObtenerUsuarioId(), solicitudId);
        return NoContent();
    }

    // Teléfono y dirección: solo las dos partes de un trabajo asignado (lo verifica la base)
    [HttpGet("{id:int}/contacto")]
    [Authorize(Roles = "cliente,trabajador")]
    public async Task<ActionResult<ContactoRespuesta>> Contacto(int id)
    {
        var contacto = await _solicitudes.ObtenerContactoAsync(User.ObtenerUsuarioId(), id);
        if (contacto == null)
        {
            return NotFound(new ErrorRespuesta("GT002", "No se encontró el contacto de este trabajo"));
        }
        return contacto;
    }
}
