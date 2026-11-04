using GestorTrabajoApi.Modelos;
using Npgsql;

namespace GestorTrabajoApi.Repositorios;

// Administración: catálogos con sus inactivos, usuarios y reportes. Que quien llama sea administrador lo
// vuelve a exigir la base (fn_exigir_administrador), además del rol del token.
public class AdminRepositorio
{
    private readonly BaseDatos _bd;

    public AdminRepositorio(BaseDatos bd)
    {
        _bd = bd;
    }

    // Catálogos

    public Task<List<ElementoAdminRespuesta>> ListarOficiosAsync(int adminId)
    {
        return ListarCatalogoAsync(adminId, "SELECT id, nombre, activo FROM oficios ORDER BY nombre", null);
    }

    public Task<List<ElementoAdminRespuesta>> ListarDepartamentosAsync(int adminId)
    {
        return ListarCatalogoAsync(adminId, "SELECT id, nombre, activo FROM departamentos ORDER BY nombre", null);
    }

    public Task<List<ElementoAdminRespuesta>> ListarMunicipiosAsync(int adminId, int departamentoId)
    {
        return ListarCatalogoAsync(adminId,
            "SELECT id, nombre, activo FROM municipios WHERE departamento_id = @padre ORDER BY nombre", departamentoId);
    }

    public Task<List<ElementoAdminRespuesta>> ListarColoniasAsync(int adminId, int municipioId)
    {
        return ListarCatalogoAsync(adminId,
            "SELECT id, nombre, activo FROM colonias WHERE municipio_id = @padre ORDER BY nombre", municipioId);
    }

    // Crear usa id nulo y editar el id del elemento. Devuelven el id.

    public Task<int> GuardarOficioAsync(int adminId, int? id, string? nombre, bool? activo)
    {
        return GuardarAsync(adminId, "SELECT fn_guardar_oficio(@admin, @id::int, @nombre::text, @activo::boolean)",
            id, null, nombre, activo);
    }

    public Task<int> GuardarDepartamentoAsync(int adminId, int? id, string? nombre, bool? activo)
    {
        return GuardarAsync(adminId, "SELECT fn_guardar_departamento(@admin, @id::int, @nombre::text, @activo::boolean)",
            id, null, nombre, activo);
    }

    public Task<int> GuardarMunicipioAsync(int adminId, int? id, int? departamentoId, string? nombre, bool? activo)
    {
        return GuardarAsync(adminId,
            "SELECT fn_guardar_municipio(@admin, @id::int, @padre::int, @nombre::text, @activo::boolean)",
            id, departamentoId, nombre, activo, true);
    }

    public Task<int> GuardarColoniaAsync(int adminId, int? id, int? municipioId, string? nombre, bool? activo)
    {
        return GuardarAsync(adminId,
            "SELECT fn_guardar_colonia(@admin, @id::int, @padre::int, @nombre::text, @activo::boolean)",
            id, municipioId, nombre, activo, true);
    }

    // Usuarios

    public async Task<List<UsuarioAdminRespuesta>> BuscarUsuariosAsync(int adminId, string? texto)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT id, rol, nombre, estado, promedio_calificacion, total_calificaciones, fecha_registro " +
            "FROM fn_buscar_usuarios(@admin, @texto::text)");
        comando.Parameters.AddWithValue("admin", adminId);
        comando.Parameters.AddWithValue("texto", (object?)texto ?? DBNull.Value);

        var usuarios = new List<UsuarioAdminRespuesta>();
        await using var lector = await comando.ExecuteReaderAsync();
        while (await lector.ReadAsync())
        {
            usuarios.Add(new UsuarioAdminRespuesta(
                lector.GetInt32(0), lector.GetString(1), lector.GetString(2), lector.GetString(3),
                lector.GetDecimal(4), lector.GetInt32(5), lector.GetFieldValue<DateTimeOffset>(6)));
        }
        return usuarios;
    }

    // estado: "activo" o "suspendido"
    public Task CambiarEstadoUsuarioAsync(int adminId, int usuarioId, string estado)
    {
        return _bd.EnTransaccionAsync(adminId, async conexion =>
        {
            await using var comando = new NpgsqlCommand("SELECT fn_cambiar_estado_usuario(@admin, @usuario, @estado)", conexion);
            comando.Parameters.AddWithValue("admin", adminId);
            comando.Parameters.AddWithValue("usuario", usuarioId);
            comando.Parameters.AddWithValue("estado", estado);
            await comando.ExecuteScalarAsync();
        });
    }

    // La función lanza GT002 si el usuario no existe
    public async Task<AuditoriaRespuesta?> ObtenerAuditoriaAsync(int adminId, int usuarioId)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT id, rol, nombre, correo, telefono, dui, estado, fecha_registro, zona FROM fn_auditoria_usuario(@admin, @usuario)");
        comando.Parameters.AddWithValue("admin", adminId);
        comando.Parameters.AddWithValue("usuario", usuarioId);
        await using var lector = await comando.ExecuteReaderAsync();
        if (!await lector.ReadAsync())
        {
            return null;
        }
        return new AuditoriaRespuesta(
            lector.GetInt32(0), lector.GetString(1), lector.GetString(2), lector.GetString(3),
            TextoONulo(lector, 4), TextoONulo(lector, 5), lector.GetString(6),
            lector.GetFieldValue<DateTimeOffset>(7), TextoONulo(lector, 8));
    }

    // Reportes

    public async Task<ReporteResumenRespuesta> ObtenerResumenAsync(int adminId)
    {
        await ExigirAdministradorAsync(adminId);
        await using var comando = _bd.ComandoLectura(
            "SELECT total_solicitudes, publicadas, asignadas, en_proceso, finalizadas, canceladas, vencidas, " +
            "total_calificaciones, promedio_general, clientes, trabajadores, suspendidos FROM vw_reporte_resumen");
        await using var lector = await comando.ExecuteReaderAsync();
        await lector.ReadAsync();
        return new ReporteResumenRespuesta(
            lector.GetInt32(0), lector.GetInt32(1), lector.GetInt32(2), lector.GetInt32(3), lector.GetInt32(4),
            lector.GetInt32(5), lector.GetInt32(6), lector.GetInt32(7), lector.GetDecimal(8),
            lector.GetInt32(9), lector.GetInt32(10), lector.GetInt32(11));
    }

    private async Task ExigirAdministradorAsync(int adminId)
    {
        await using var comando = _bd.ComandoLectura("SELECT fn_exigir_administrador(@admin)");
        comando.Parameters.AddWithValue("admin", adminId);
        await comando.ExecuteScalarAsync();
    }

    // sql trae una columna id, nombre y activo, y @padre si se filtra por un padre
    private async Task<List<ElementoAdminRespuesta>> ListarCatalogoAsync(int adminId, string sql, int? padreId)
    {
        await ExigirAdministradorAsync(adminId);
        await using var comando = _bd.ComandoLectura(sql);
        if (padreId.HasValue)
        {
            comando.Parameters.AddWithValue("padre", padreId.Value);
        }

        var elementos = new List<ElementoAdminRespuesta>();
        await using var lector = await comando.ExecuteReaderAsync();
        while (await lector.ReadAsync())
        {
            elementos.Add(new ElementoAdminRespuesta(lector.GetInt32(0), lector.GetString(1), lector.GetBoolean(2)));
        }
        return elementos;
    }

    private Task<int> GuardarAsync(int adminId, string sql, int? id, int? padreId, string? nombre, bool? activo,
                                   bool conPadre = false)
    {
        return _bd.EnTransaccionAsync(adminId, async conexion =>
        {
            await using var comando = new NpgsqlCommand(sql, conexion);
            comando.Parameters.AddWithValue("admin", adminId);
            comando.Parameters.AddWithValue("id", (object?)id ?? DBNull.Value);
            if (conPadre)
            {
                comando.Parameters.AddWithValue("padre", (object?)padreId ?? DBNull.Value);
            }
            comando.Parameters.AddWithValue("nombre", (object?)nombre ?? DBNull.Value);
            comando.Parameters.AddWithValue("activo", (object?)activo ?? DBNull.Value);
            return (int)(await comando.ExecuteScalarAsync())!;
        });
    }

    private static string? TextoONulo(NpgsqlDataReader lector, int columna)
    {
        return lector.IsDBNull(columna) ? null : lector.GetString(columna);
    }
}
