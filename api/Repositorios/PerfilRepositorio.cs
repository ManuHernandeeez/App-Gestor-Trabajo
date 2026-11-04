using GestorTrabajoApi.Modelos;
using Npgsql;

namespace GestorTrabajoApi.Repositorios;

// Perfil propio: lectura y edición de datos, oficios y colonias. La foto se agrega después.
public class PerfilRepositorio
{
    private readonly BaseDatos _bd;

    public PerfilRepositorio(BaseDatos bd)
    {
        _bd = bd;
    }

    public Task ActualizarAsync(int usuarioId, PerfilEdicion datos)
    {
        return _bd.EnTransaccionAsync(usuarioId, async conexion =>
        {
            await using var comando = new NpgsqlCommand(
                "SELECT fn_actualizar_perfil(@usuario, @nombre::text, @telefono::text, @municipio::int, @colonia::int)",
                conexion);
            comando.Parameters.AddWithValue("usuario", usuarioId);
            comando.Parameters.AddWithValue("nombre", Valor(datos.Nombre));
            comando.Parameters.AddWithValue("telefono", Valor(datos.Telefono));
            comando.Parameters.AddWithValue("municipio", Valor(datos.MunicipioId));
            comando.Parameters.AddWithValue("colonia", Valor(datos.ColoniaId));
            await comando.ExecuteNonQueryAsync();
        });
    }

    public Task ReemplazarOficiosAsync(int usuarioId, OficiosEdicion datos)
    {
        return _bd.EnTransaccionAsync(usuarioId, async conexion =>
        {
            await using var comando = new NpgsqlCommand("SELECT fn_reemplazar_oficios(@usuario, @oficios)", conexion);
            comando.Parameters.AddWithValue("usuario", usuarioId);
            comando.Parameters.AddWithValue("oficios", (datos.Oficios ?? new List<int>()).ToArray());
            await comando.ExecuteNonQueryAsync();
        });
    }

    public Task ReemplazarColoniasAsync(int usuarioId, ColoniasEdicion datos)
    {
        return _bd.EnTransaccionAsync(usuarioId, async conexion =>
        {
            await using var comando = new NpgsqlCommand("SELECT fn_reemplazar_colonias(@usuario, @colonias)", conexion);
            comando.Parameters.AddWithValue("usuario", usuarioId);
            comando.Parameters.AddWithValue("colonias", (datos.Colonias ?? new List<int>()).ToArray());
            await comando.ExecuteNonQueryAsync();
        });
    }

    public async Task<PerfilRespuesta?> ObtenerAsync(int usuarioId)
    {
        await using var comando = _bd.ComandoLectura(
            @"SELECT u.id, u.rol, u.nombre, u.telefono, u.dui, u.foto_ruta,
                     u.promedio_calificacion, u.total_calificaciones,
                     d.id, d.nombre, m.id, m.nombre, c.id, c.nombre
              FROM usuarios u
              LEFT JOIN municipios m ON m.id = u.municipio_id
              LEFT JOIN departamentos d ON d.id = m.departamento_id
              LEFT JOIN colonias c ON c.id = u.colonia_id
              WHERE u.id = @id AND NOT u.eliminado");
        comando.Parameters.AddWithValue("id", usuarioId);
        await using var lector = await comando.ExecuteReaderAsync();
        if (!await lector.ReadAsync())
        {
            return null;
        }

        var fotoRuta = TextoONulo(lector, 5);
        return new PerfilRespuesta(
            lector.GetInt32(0),
            lector.GetString(1),
            lector.GetString(2),
            TextoONulo(lector, 3),
            EnmascararDui(TextoONulo(lector, 4)),
            fotoRuta == null ? null : "fotos/" + fotoRuta,
            lector.GetDecimal(6),
            lector.GetInt32(7),
            ElementoONulo(lector, 8, 9),
            ElementoONulo(lector, 10, 11),
            ElementoONulo(lector, 12, 13),
            await ListarOficiosAsync(usuarioId),
            await ListarColoniasTrabajoAsync(usuarioId));
    }

    private Task<List<ElementoCatalogo>> ListarOficiosAsync(int usuarioId)
    {
        var comando = _bd.ComandoLectura(
            "SELECT o.id, o.nombre FROM usuario_oficio uo JOIN oficios o ON o.id = uo.oficio_id " +
            "WHERE uo.usuario_id = @id ORDER BY o.nombre");
        comando.Parameters.AddWithValue("id", usuarioId);
        return BaseDatos.LeerElementosAsync(comando);
    }

    private Task<List<ElementoCatalogo>> ListarColoniasTrabajoAsync(int usuarioId)
    {
        var comando = _bd.ComandoLectura(
            "SELECT c.id, c.nombre FROM trabajador_colonia tc JOIN colonias c ON c.id = tc.colonia_id " +
            "WHERE tc.usuario_id = @id ORDER BY c.nombre");
        comando.Parameters.AddWithValue("id", usuarioId);
        return BaseDatos.LeerElementosAsync(comando);
    }

    private static object Valor(object? valor)
    {
        return valor ?? DBNull.Value;
    }

    private static string? TextoONulo(NpgsqlDataReader lector, int columna)
    {
        return lector.IsDBNull(columna) ? null : lector.GetString(columna);
    }

    private static ElementoCatalogo? ElementoONulo(NpgsqlDataReader lector, int columnaId, int columnaNombre)
    {
        if (lector.IsDBNull(columnaId))
        {
            return null;
        }
        return new ElementoCatalogo(lector.GetInt32(columnaId), lector.GetString(columnaNombre));
    }

    // 12345678-4 se muestra como ******78-4
    private static string? EnmascararDui(string? dui)
    {
        return dui == null ? null : new string('*', 6) + dui.Substring(6);
    }
}
