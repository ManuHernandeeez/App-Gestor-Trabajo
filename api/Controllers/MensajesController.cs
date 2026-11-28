using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GestorTrabajoApi.Controllers;

// Chat de texto entre el cliente y un trabajador que envió propuesta a su solicitud (un hilo por trabajador).
// Los mensajes viven en la base y la app los pide al abrir la pantalla y cada pocos segundos mientras está a la vista.
// Quién puede leer y escribir lo decide la base. otraParteId es el trabajador con quien habla el cliente; el
// trabajador no necesita indicarlo, y el cliente tampoco cuando el trabajo ya tiene trabajador asignado.
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
    public Task<List<MensajeRespuesta>> Listar(int id, [FromQuery] DateTimeOffset? desde, [FromQuery] int? otraParteId)
    {
        return _mensajes.ListarAsync(User.ObtenerUsuarioId(), id, desde, otraParteId);
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
