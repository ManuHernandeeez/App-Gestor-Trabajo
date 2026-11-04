using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GestorTrabajoApi.Controllers;

// Avisos y la carga de lo nuevo al abrir la app. Siempre del usuario del token.
[ApiController]
[Route("api")]
[Authorize(Roles = "cliente,trabajador")]
public class AvisosController : ControllerBase
{
    private readonly AvisoRepositorio _avisos;

    public AvisosController(AvisoRepositorio avisos)
    {
        _avisos = avisos;
    }

    [HttpGet("sincronizacion")]
    public Task<SincronizacionRespuesta> Sincronizar([FromQuery] DateTimeOffset? desde)
    {
        return _avisos.SincronizarAsync(User.ObtenerUsuarioId(), desde);
    }

    // Sin cuerpo marca todos los avisos del usuario
    [HttpPut("avisos/leidos")]
    public async Task<AvisosLeidosRespuesta> MarcarLeidos(AvisosLeidosEdicion? datos)
    {
        var marcados = await _avisos.MarcarLeidosAsync(User.ObtenerUsuarioId(), datos ?? new AvisosLeidosEdicion());
        return new AvisosLeidosRespuesta(marcados);
    }
}
