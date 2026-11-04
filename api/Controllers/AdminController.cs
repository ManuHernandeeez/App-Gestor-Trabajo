using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GestorTrabajoApi.Controllers;

// Administración: catálogos de oficios y zonas, usuarios y reportes. Solo el rol administrador.
// Nada se borra: los catálogos se desactivan y los usuarios se suspenden.
[ApiController]
[Route("api/admin")]
[Authorize(Roles = "administrador")]
public class AdminController : ControllerBase
{
    private readonly AdminRepositorio _admin;

    public AdminController(AdminRepositorio admin)
    {
        _admin = admin;
    }

    // Oficios

    [HttpGet("oficios")]
    public Task<List<ElementoAdminRespuesta>> Oficios()
    {
        return _admin.ListarOficiosAsync(User.ObtenerUsuarioId());
    }

    [HttpPost("oficios")]
    public async Task<ActionResult<CatalogoCreadoRespuesta>> CrearOficio(CatalogoNuevo datos)
    {
        var id = await _admin.GuardarOficioAsync(User.ObtenerUsuarioId(), null, datos.Nombre, datos.Activo);
        return StatusCode(StatusCodes.Status201Created, new CatalogoCreadoRespuesta(id));
    }

    [HttpPut("oficios/{id:int}")]
    public async Task<IActionResult> EditarOficio(int id, CatalogoEdicion datos)
    {
        await _admin.GuardarOficioAsync(User.ObtenerUsuarioId(), id, datos.Nombre, datos.Activo);
        return NoContent();
    }

    // Departamentos

    [HttpGet("departamentos")]
    public Task<List<ElementoAdminRespuesta>> Departamentos()
    {
        return _admin.ListarDepartamentosAsync(User.ObtenerUsuarioId());
    }

    [HttpPost("departamentos")]
    public async Task<ActionResult<CatalogoCreadoRespuesta>> CrearDepartamento(CatalogoNuevo datos)
    {
        var id = await _admin.GuardarDepartamentoAsync(User.ObtenerUsuarioId(), null, datos.Nombre, datos.Activo);
        return StatusCode(StatusCodes.Status201Created, new CatalogoCreadoRespuesta(id));
    }

    [HttpPut("departamentos/{id:int}")]
    public async Task<IActionResult> EditarDepartamento(int id, CatalogoEdicion datos)
    {
        await _admin.GuardarDepartamentoAsync(User.ObtenerUsuarioId(), id, datos.Nombre, datos.Activo);
        return NoContent();
    }

    // Municipios: se listan por departamento

    [HttpGet("municipios")]
    public async Task<ActionResult<List<ElementoAdminRespuesta>>> Municipios([FromQuery] int? departamentoId)
    {
        if (departamentoId == null)
        {
            return BadRequest(new ErrorRespuesta("SOLICITUD_INVALIDA", "Indica el departamento (departamentoId)"));
        }
        return await _admin.ListarMunicipiosAsync(User.ObtenerUsuarioId(), departamentoId.Value);
    }

    [HttpPost("municipios")]
    public async Task<ActionResult<CatalogoCreadoRespuesta>> CrearMunicipio(CatalogoNuevo datos)
    {
        var id = await _admin.GuardarMunicipioAsync(
            User.ObtenerUsuarioId(), null, datos.DepartamentoId, datos.Nombre, datos.Activo);
        return StatusCode(StatusCodes.Status201Created, new CatalogoCreadoRespuesta(id));
    }

    [HttpPut("municipios/{id:int}")]
    public async Task<IActionResult> EditarMunicipio(int id, CatalogoEdicion datos)
    {
        await _admin.GuardarMunicipioAsync(User.ObtenerUsuarioId(), id, null, datos.Nombre, datos.Activo);
        return NoContent();
    }

    // Colonias: se listan por municipio

    [HttpGet("colonias")]
    public async Task<ActionResult<List<ElementoAdminRespuesta>>> Colonias([FromQuery] int? municipioId)
    {
        if (municipioId == null)
        {
            return BadRequest(new ErrorRespuesta("SOLICITUD_INVALIDA", "Indica el municipio (municipioId)"));
        }
        return await _admin.ListarColoniasAsync(User.ObtenerUsuarioId(), municipioId.Value);
    }

    [HttpPost("colonias")]
    public async Task<ActionResult<CatalogoCreadoRespuesta>> CrearColonia(CatalogoNuevo datos)
    {
        var id = await _admin.GuardarColoniaAsync(
            User.ObtenerUsuarioId(), null, datos.MunicipioId, datos.Nombre, datos.Activo);
        return StatusCode(StatusCodes.Status201Created, new CatalogoCreadoRespuesta(id));
    }

    [HttpPut("colonias/{id:int}")]
    public async Task<IActionResult> EditarColonia(int id, CatalogoEdicion datos)
    {
        await _admin.GuardarColoniaAsync(User.ObtenerUsuarioId(), id, null, datos.Nombre, datos.Activo);
        return NoContent();
    }

    // Usuarios

    [HttpGet("usuarios")]
    public Task<List<UsuarioAdminRespuesta>> BuscarUsuarios([FromQuery] string? q)
    {
        return _admin.BuscarUsuariosAsync(User.ObtenerUsuarioId(), q);
    }

    [HttpPut("usuarios/{id:int}/suspender")]
    public async Task<IActionResult> Suspender(int id)
    {
        await _admin.CambiarEstadoUsuarioAsync(User.ObtenerUsuarioId(), id, "suspendido");
        return NoContent();
    }

    [HttpPut("usuarios/{id:int}/reactivar")]
    public async Task<IActionResult> Reactivar(int id)
    {
        await _admin.CambiarEstadoUsuarioAsync(User.ObtenerUsuarioId(), id, "activo");
        return NoContent();
    }

    // DUI, teléfono y correo: solo salen aquí y en el contacto de un trabajo asignado
    [HttpGet("usuarios/{id:int}/auditoria")]
    public async Task<ActionResult<AuditoriaRespuesta>> Auditoria(int id)
    {
        var auditoria = await _admin.ObtenerAuditoriaAsync(User.ObtenerUsuarioId(), id);
        if (auditoria == null)
        {
            return NotFound(new ErrorRespuesta("GT002", "El usuario no existe"));
        }
        return auditoria;
    }

    // Reportes

    [HttpGet("reportes/resumen")]
    public Task<ReporteResumenRespuesta> Resumen()
    {
        return _admin.ObtenerResumenAsync(User.ObtenerUsuarioId());
    }
}
