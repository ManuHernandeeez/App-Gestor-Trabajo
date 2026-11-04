using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;
using GestorTrabajoApi.Servicios;
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
    private readonly FotoServicio _fotos;

    public UsuariosController(PerfilRepositorio perfiles, FotoServicio fotos)
    {
        _perfiles = perfiles;
        _fotos = fotos;
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

    // Multipart con el campo "foto". Solo JPG o PNG de hasta 2 MB; el archivo se guarda con un nombre generado.
    [HttpPost("foto")]
    [RequestSizeLimit(FotoServicio.Maximo + 64 * 1024)]
    public async Task<ActionResult<FotoRespuesta>> SubirFoto(IFormFile? foto)
    {
        if (foto == null || foto.Length == 0)
        {
            return BadRequest(new ErrorRespuesta("SOLICITUD_INVALIDA", "Envía la foto en el campo \"foto\""));
        }
        if (foto.Length > FotoServicio.Maximo)
        {
            return BadRequest(new ErrorRespuesta("SOLICITUD_INVALIDA", "La foto no puede pasar de 2 MB"));
        }

        using var memoria = new MemoryStream();
        await foto.CopyToAsync(memoria);
        var datos = memoria.ToArray();
        var extension = FotoServicio.ExtensionDe(datos);
        if (extension == null)
        {
            return BadRequest(new ErrorRespuesta("SOLICITUD_INVALIDA", "La foto debe ser JPG o PNG"));
        }

        var nombre = await _fotos.GuardarAsync(datos, extension);
        try
        {
            var anterior = await _perfiles.ActualizarFotoAsync(User.ObtenerUsuarioId(), nombre);
            _fotos.Borrar(anterior);
        }
        catch
        {
            // la base no aceptó la foto: no se deja el archivo huérfano
            _fotos.Borrar(nombre);
            throw;
        }
        return new FotoRespuesta("fotos/" + nombre);
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
