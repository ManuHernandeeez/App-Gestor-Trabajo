using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GestorTrabajoApi.Controllers;

// Catálogos de zona y oficios. Son públicos porque el registro los necesita antes de tener sesión.
[ApiController]
[Route("api/catalogos")]
[AllowAnonymous]
public class ZonasController : ControllerBase
{
    private readonly CatalogoRepositorio _catalogos;

    public ZonasController(CatalogoRepositorio catalogos)
    {
        _catalogos = catalogos;
    }

    [HttpGet("departamentos")]
    public Task<List<ElementoCatalogo>> Departamentos()
    {
        return _catalogos.ListarDepartamentosAsync();
    }

    [HttpGet("departamentos/{id:int}/municipios")]
    public Task<List<ElementoCatalogo>> Municipios(int id)
    {
        return _catalogos.ListarMunicipiosAsync(id);
    }

    [HttpGet("municipios/{id:int}/colonias")]
    public Task<List<ElementoCatalogo>> Colonias(int id)
    {
        return _catalogos.ListarColoniasAsync(id);
    }

    [HttpGet("oficios")]
    public Task<List<ElementoCatalogo>> Oficios()
    {
        return _catalogos.ListarOficiosAsync();
    }
}
