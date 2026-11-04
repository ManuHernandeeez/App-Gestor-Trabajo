using GestorTrabajoApi.Modelos;
using Npgsql;

namespace GestorTrabajoApi.Repositorios;

// Solicitudes del cliente: publicar y listar las propias.
public class SolicitudRepositorio
{
    private readonly BaseDatos _bd;

    public SolicitudRepositorio(BaseDatos bd)
    {
        _bd = bd;
    }

    public Task<int> PublicarAsync(int clienteId, SolicitudNueva datos)
    {
        return _bd.EnTransaccionAsync(clienteId, async conexion =>
        {
            await using var comando = new NpgsqlCommand(
                "SELECT fn_publicar_solicitud(@cliente, @oficio::int, @colonia::int, @titulo::text, " +
                "@descripcion::text, @presupuesto::numeric, @direccion::text)", conexion);
            comando.Parameters.AddWithValue("cliente", clienteId);
            comando.Parameters.AddWithValue("oficio", Valor(datos.OficioId));
            comando.Parameters.AddWithValue("colonia", Valor(datos.ColoniaId));
            comando.Parameters.AddWithValue("titulo", Valor(datos.Titulo));
            comando.Parameters.AddWithValue("descripcion", Valor(datos.Descripcion));
            comando.Parameters.AddWithValue("presupuesto", Valor(datos.Presupuesto));
            comando.Parameters.AddWithValue("direccion", Valor(datos.DireccionExacta));
            return (int)(await comando.ExecuteScalarAsync())!;
        });
    }

    // estado es opcional: null trae todas.
    public async Task<List<SolicitudResumenRespuesta>> ListarDeClienteAsync(int clienteId, string? estado)
    {
        await using var comando = _bd.ComandoLectura(
            @"SELECT s.id, s.titulo, o.nombre, m.nombre || ', Col. ' || c.nombre, s.presupuesto, s.estado,
                     s.fecha_publicacion,
                     (SELECT count(*) FROM ofertas f WHERE f.solicitud_id = s.id AND f.estado <> 'retirada')::int
              FROM solicitudes s
              JOIN oficios o ON o.id = s.oficio_id
              JOIN colonias c ON c.id = s.colonia_id
              JOIN municipios m ON m.id = c.municipio_id
              WHERE s.cliente_id = @cliente AND NOT s.eliminado
                AND (@estado::text IS NULL OR s.estado = @estado::text)
              ORDER BY s.fecha_publicacion DESC");
        comando.Parameters.AddWithValue("cliente", clienteId);
        comando.Parameters.AddWithValue("estado", Valor(estado));

        var solicitudes = new List<SolicitudResumenRespuesta>();
        await using var lector = await comando.ExecuteReaderAsync();
        while (await lector.ReadAsync())
        {
            solicitudes.Add(new SolicitudResumenRespuesta(
                lector.GetInt32(0), lector.GetString(1), lector.GetString(2), lector.GetString(3),
                lector.GetDecimal(4), lector.GetString(5), lector.GetFieldValue<DateTimeOffset>(6), lector.GetInt32(7)));
        }
        return solicitudes;
    }

    public async Task<SolicitudDetalleRespuesta?> ObtenerDetalleAsync(int usuarioId, int solicitudId)
    {
        var detalle = await LeerDetalleAsync(usuarioId, solicitudId);
        if (detalle == null)
        {
            return null;
        }
        return detalle with { YaCalifique = await YaCalificoAsync(usuarioId, solicitudId) };
    }

    private async Task<bool> YaCalificoAsync(int usuarioId, int solicitudId)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT EXISTS (SELECT 1 FROM calificaciones WHERE solicitud_id = @solicitud AND calificador_id = @usuario)");
        comando.Parameters.AddWithValue("solicitud", solicitudId);
        comando.Parameters.AddWithValue("usuario", usuarioId);
        return (bool)(await comando.ExecuteScalarAsync())!;
    }

    // Los permisos (dueño, zona, propuesta o asignado) los revisa fn_detalle_solicitud.
    private async Task<SolicitudDetalleRespuesta?> LeerDetalleAsync(int usuarioId, int solicitudId)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT id, titulo, descripcion, oficio, zona, presupuesto, estado, fecha_publicacion, cliente_id, " +
            "cliente_nombre, trabajador_nombre, propuestas, mi_propuesta_id, mi_propuesta_precio, mi_propuesta_estado " +
            "FROM fn_detalle_solicitud(@usuario, @solicitud)");
        comando.Parameters.AddWithValue("usuario", usuarioId);
        comando.Parameters.AddWithValue("solicitud", solicitudId);
        await using var lector = await comando.ExecuteReaderAsync();
        if (!await lector.ReadAsync())
        {
            return null;
        }

        MiPropuestaRespuesta? miPropuesta = null;
        if (!lector.IsDBNull(12))
        {
            miPropuesta = new MiPropuestaRespuesta(lector.GetInt32(12), lector.GetDecimal(13), lector.GetString(14));
        }
        return new SolicitudDetalleRespuesta(
            lector.GetInt32(0), lector.GetString(1), lector.GetString(2), lector.GetString(3), lector.GetString(4),
            lector.GetDecimal(5), lector.GetString(6), lector.GetFieldValue<DateTimeOffset>(7), lector.GetInt32(8),
            lector.GetString(9),
            lector.IsDBNull(10) ? null : lector.GetString(10),
            lector.IsDBNull(11) ? null : lector.GetInt32(11),
            miPropuesta);
    }

    public Task CancelarAsync(int clienteId, int solicitudId)
    {
        return EjecutarAsync(clienteId, "SELECT fn_cancelar_solicitud(@usuario, @solicitud)", solicitudId);
    }

    public Task FinalizarAsync(int clienteId, int solicitudId)
    {
        return EjecutarAsync(clienteId, "SELECT fn_finalizar_solicitud(@usuario, @solicitud)", solicitudId);
    }

    public Task MarcarEnProcesoAsync(int trabajadorId, int solicitudId)
    {
        return EjecutarAsync(trabajadorId, "SELECT fn_marcar_en_proceso(@usuario, @solicitud)", solicitudId);
    }

    // fn_contacto_trabajo lanza GT003 si quien pregunta no es una de las dos partes o el trabajo no está asignado.
    public async Task<ContactoRespuesta?> ObtenerContactoAsync(int usuarioId, int solicitudId)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT rol, nombre, telefono, direccion_exacta FROM fn_contacto_trabajo(@usuario, @solicitud)");
        comando.Parameters.AddWithValue("usuario", usuarioId);
        comando.Parameters.AddWithValue("solicitud", solicitudId);
        await using var lector = await comando.ExecuteReaderAsync();
        if (!await lector.ReadAsync())
        {
            return null;
        }
        return new ContactoRespuesta(
            lector.GetString(0), lector.GetString(1),
            lector.IsDBNull(2) ? null : lector.GetString(2),
            lector.IsDBNull(3) ? null : lector.GetString(3));
    }

    // Llama a una función fn_... que recibe (usuario, solicitud) dentro de una transacción.
    private Task EjecutarAsync(int usuarioId, string sql, int solicitudId)
    {
        return _bd.EnTransaccionAsync(usuarioId, async conexion =>
        {
            await using var comando = new NpgsqlCommand(sql, conexion);
            comando.Parameters.AddWithValue("usuario", usuarioId);
            comando.Parameters.AddWithValue("solicitud", solicitudId);
            await comando.ExecuteScalarAsync();
        });
    }

    private static object Valor(object? valor)
    {
        return valor ?? DBNull.Value;
    }
}
