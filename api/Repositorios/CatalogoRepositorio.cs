using GestorTrabajoApi.Modelos;

namespace GestorTrabajoApi.Repositorios;

// Catálogos públicos: solo salen los registros activos.
public class CatalogoRepositorio
{
    private readonly BaseDatos _bd;

    public CatalogoRepositorio(BaseDatos bd)
    {
        _bd = bd;
    }

    public Task<List<ElementoCatalogo>> ListarDepartamentosAsync()
    {
        var comando = _bd.ComandoLectura("SELECT id, nombre FROM departamentos WHERE activo ORDER BY nombre");
        return BaseDatos.LeerElementosAsync(comando);
    }

    public Task<List<ElementoCatalogo>> ListarMunicipiosAsync(int departamentoId)
    {
        var comando = _bd.ComandoLectura(
            "SELECT id, nombre FROM municipios WHERE departamento_id = @id AND activo ORDER BY nombre");
        comando.Parameters.AddWithValue("id", departamentoId);
        return BaseDatos.LeerElementosAsync(comando);
    }

    public Task<List<ElementoCatalogo>> ListarColoniasAsync(int municipioId)
    {
        var comando = _bd.ComandoLectura(
            "SELECT id, nombre FROM colonias WHERE municipio_id = @id AND activo ORDER BY nombre");
        comando.Parameters.AddWithValue("id", municipioId);
        return BaseDatos.LeerElementosAsync(comando);
    }

    public Task<List<ElementoCatalogo>> ListarOficiosAsync()
    {
        var comando = _bd.ComandoLectura("SELECT id, nombre FROM oficios WHERE activo ORDER BY nombre");
        return BaseDatos.LeerElementosAsync(comando);
    }
}
