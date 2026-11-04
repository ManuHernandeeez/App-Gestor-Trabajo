using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GestorTrabajoApi.Controllers;

// Cliente y trabajador se califican al terminar el trabajo. Las reglas las aplica fn_calificar.
[ApiController]
[Route("api")]
[Authorize(Roles = "cliente,trabajador")]
public class CalificacionesController : ControllerBase
{
    private readonly CalificacionRepositorio _calificaciones;

    public CalificacionesController(CalificacionRepositorio calificaciones)
    {
        _calificaciones = calificaciones;
    }

    [HttpPost("solicitudes/{id:int}/calificaciones")]
    public async Task<ActionResult<CalificacionCreadaRespuesta>> Calificar(int id, CalificacionNueva calificacion)
    {
        var calificacionId = await _calificaciones.CalificarAsync(User.ObtenerUsuarioId(), id, calificacion);
        return StatusCode(StatusCodes.Status201Created, new CalificacionCreadaRespuesta(calificacionId));
    }

    [HttpGet("usuarios/{id:int}/reputacion")]
    public async Task<ActionResult<ReputacionRespuesta>> Reputacion(int id)
    {
        var reputacion = await _calificaciones.ObtenerReputacionAsync(id);
        if (reputacion == null)
        {
            return NotFound(new ErrorRespuesta("GT002", "El usuario no existe"));
        }
        return reputacion;
    }
}
