using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GestorTrabajoApi.Controllers;

// Mensajes de texto entre el cliente y el trabajador asignado. Se piden al abrir la pantalla; no hay tiempo real.
// Quién puede leer y escribir lo decide la base.
[ApiController]
[Route("api")]
[Authorize(Roles = "cliente,trabajador")]
public class MensajesController : ControllerBase
{
    private readonly MensajeRepositorio _mensajes;

    public MensajesController(MensajeRepositorio mensajes)
    {
        _mensajes = mensajes;
    }

    [HttpGet("solicitudes/{id:int}/mensajes")]
    public Task<List<MensajeRespuesta>> Listar(int id, [FromQuery] DateTimeOffset? desde)
    {
        return _mensajes.ListarAsync(User.ObtenerUsuarioId(), id, desde);
    }

    [HttpPost("solicitudes/{id:int}/mensajes")]
    public async Task<ActionResult<MensajeCreadoRespuesta>> Enviar(int id, MensajeNuevo mensaje)
    {
        var mensajeId = await _mensajes.EnviarAsync(User.ObtenerUsuarioId(), id, mensaje);
        return StatusCode(StatusCodes.Status201Created, new MensajeCreadoRespuesta(mensajeId));
    }

    [HttpGet("conversaciones")]
    public Task<List<ConversacionRespuesta>> Conversaciones()
    {
        return _mensajes.ListarConversacionesAsync(User.ObtenerUsuarioId());
    }
}
