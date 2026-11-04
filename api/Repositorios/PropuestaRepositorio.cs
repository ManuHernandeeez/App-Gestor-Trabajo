using GestorTrabajoApi.Modelos;
using Npgsql;

namespace GestorTrabajoApi.Repositorios;

// Propuestas (ofertas): lo que ve y hace el cliente dueño de la solicitud y lo que hace el trabajador.
public class PropuestaRepositorio
{
    private readonly BaseDatos _bd;

    public PropuestaRepositorio(BaseDatos bd)
    {
        _bd = bd;
    }

    // Cliente

    public async Task<List<PropuestaDeSolicitudRespuesta>> ListarDeSolicitudAsync(int clienteId, int solicitudId)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT id, trabajador_id, trabajador_nombre, promedio_calificacion, total_calificaciones, " +
            "precio, mensaje, estado, fecha FROM fn_propuestas_de_solicitud(@cliente, @solicitud)");
        comando.Parameters.AddWithValue("cliente", clienteId);
        comando.Parameters.AddWithValue("solicitud", solicitudId);

        var propuestas = new List<PropuestaDeSolicitudRespuesta>();
        await using var lector = await comando.ExecuteReaderAsync();
        while (await lector.ReadAsync())
        {
            propuestas.Add(new PropuestaDeSolicitudRespuesta(
                lector.GetInt32(0), lector.GetInt32(1), lector.GetString(2), lector.GetDecimal(3), lector.GetInt32(4),
                lector.GetDecimal(5), TextoONulo(lector, 6), lector.GetString(7), lector.GetFieldValue<DateTimeOffset>(8)));
        }
        return propuestas;
    }

    public Task AceptarAsync(int clienteId, int propuestaId)
    {
        return EjecutarAsync(clienteId, "SELECT fn_aceptar_oferta(@usuario, @propuesta)", propuestaId);
    }

    public Task RechazarAsync(int clienteId, int propuestaId)
    {
        return EjecutarAsync(clienteId, "SELECT fn_rechazar_oferta(@usuario, @propuesta)", propuestaId);
    }

    // Trabajador

    public async Task<List<TrabajoZonaRespuesta>> ListarZonaAsync(int trabajadorId, int? oficioId)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT id, titulo, oficio, presupuesto, zona, cliente_nombre, publicada_hace_horas, ya_propuse " +
            "FROM fn_trabajos_por_zona(@trabajador, @oficio::int)");
        comando.Parameters.AddWithValue("trabajador", trabajadorId);
        comando.Parameters.AddWithValue("oficio", (object?)oficioId ?? DBNull.Value);

        var trabajos = new List<TrabajoZonaRespuesta>();
        await using var lector = await comando.ExecuteReaderAsync();
        while (await lector.ReadAsync())
        {
            trabajos.Add(new TrabajoZonaRespuesta(
                lector.GetInt32(0), lector.GetString(1), lector.GetString(2), lector.GetDecimal(3), lector.GetString(4),
                lector.GetString(5), lector.GetInt32(6), lector.GetBoolean(7)));
        }
        return trabajos;
    }

    public Task<int> EnviarAsync(int trabajadorId, int solicitudId, PropuestaNueva datos)
    {
        return _bd.EnTransaccionAsync(trabajadorId, async conexion =>
        {
            await using var comando = new NpgsqlCommand(
                "SELECT fn_enviar_oferta(@trabajador, @solicitud, @precio::numeric, @mensaje::text)", conexion);
            comando.Parameters.AddWithValue("trabajador", trabajadorId);
            comando.Parameters.AddWithValue("solicitud", solicitudId);
            comando.Parameters.AddWithValue("precio", (object?)datos.Precio ?? DBNull.Value);
            comando.Parameters.AddWithValue("mensaje", (object?)datos.Mensaje ?? DBNull.Value);
            return (int)(await comando.ExecuteScalarAsync())!;
        });
    }

    public Task RetirarAsync(int trabajadorId, int propuestaId)
    {
        return EjecutarAsync(trabajadorId, "SELECT fn_retirar_oferta(@usuario, @propuesta)", propuestaId);
    }

    // estado es opcional: null trae todas.
    public async Task<List<PropuestaPropiaRespuesta>> ListarDeTrabajadorAsync(int trabajadorId, string? estado)
    {
        await using var comando = _bd.ComandoLectura(
            @"SELECT f.id, s.id, s.titulo, o.nombre, m.nombre || ', Col. ' || c.nombre, fn_nombre_corto(cl.nombre),
                     s.presupuesto, f.precio, f.mensaje, f.estado, s.estado, f.fecha
              FROM ofertas f
              JOIN solicitudes s ON s.id = f.solicitud_id
              JOIN oficios o ON o.id = s.oficio_id
              JOIN colonias c ON c.id = s.colonia_id
              JOIN municipios m ON m.id = c.municipio_id
              JOIN usuarios cl ON cl.id = s.cliente_id
              WHERE f.trabajador_id = @trabajador
                AND (@estado::text IS NULL OR f.estado = @estado::text)
              ORDER BY f.fecha DESC");
        comando.Parameters.AddWithValue("trabajador", trabajadorId);
        comando.Parameters.AddWithValue("estado", (object?)estado ?? DBNull.Value);

        var propuestas = new List<PropuestaPropiaRespuesta>();
        await using var lector = await comando.ExecuteReaderAsync();
        while (await lector.ReadAsync())
        {
            propuestas.Add(new PropuestaPropiaRespuesta(
                lector.GetInt32(0), lector.GetInt32(1), lector.GetString(2), lector.GetString(3), lector.GetString(4),
                lector.GetString(5), lector.GetDecimal(6), lector.GetDecimal(7), TextoONulo(lector, 8),
                lector.GetString(9), lector.GetString(10), lector.GetFieldValue<DateTimeOffset>(11)));
        }
        return propuestas;
    }

    // Llama a una función fn_... que recibe (usuario, propuesta) dentro de una transacción.
    private Task EjecutarAsync(int usuarioId, string sql, int propuestaId)
    {
        return _bd.EnTransaccionAsync(usuarioId, async conexion =>
        {
            await using var comando = new NpgsqlCommand(sql, conexion);
            comando.Parameters.AddWithValue("usuario", usuarioId);
            comando.Parameters.AddWithValue("propuesta", propuestaId);
            await comando.ExecuteScalarAsync();
        });
    }

    private static string? TextoONulo(NpgsqlDataReader lector, int columna)
    {
        return lector.IsDBNull(columna) ? null : lector.GetString(columna);
    }
}
