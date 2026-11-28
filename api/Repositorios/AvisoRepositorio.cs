using GestorTrabajoApi.Modelos;
using Npgsql;
using NpgsqlTypes;

namespace GestorTrabajoApi.Repositorios;

// Avisos del usuario y la sincronización de lo nuevo (mensajes y avisos) al abrir la app.
public class AvisoRepositorio
{
    private readonly BaseDatos _bd;

    public AvisoRepositorio(BaseDatos bd)
    {
        _bd = bd;
    }

    // desde es opcional: sin él (primera carga) trae los mensajes de los últimos 7 días y los avisos sin leer.
    // Ahora se toma antes de consultar: lo que llegue mientras tanto sale otra vez en la próxima carga y no se pierde.
    public async Task<SincronizacionRespuesta> SincronizarAsync(int usuarioId, DateTimeOffset? desde)
    {
        var ahora = await HoraDelServidorAsync();

        await using var comando = _bd.ComandoLectura(
            "SELECT clase, id, solicitud_id, titulo, tipo, texto, emisor_nombre, fecha, leido FROM fn_sincronizar(@usuario, @desde)");
        comando.Parameters.AddWithValue("usuario", usuarioId);
        comando.Parameters.Add(new NpgsqlParameter("desde", NpgsqlDbType.TimestampTz)
        {
            Value = desde.HasValue ? desde.Value.UtcDateTime : DBNull.Value
        });

        var mensajes = new List<MensajeSincronizadoRespuesta>();
        var avisos = new List<AvisoRespuesta>();
        await using var lector = await comando.ExecuteReaderAsync();
        while (await lector.ReadAsync())
        {
            if (lector.GetString(0) == "mensaje")
            {
                mensajes.Add(new MensajeSincronizadoRespuesta(
                    lector.GetInt32(1), lector.GetInt32(2), lector.GetString(3), lector.GetString(6),
                    lector.GetString(5), lector.GetFieldValue<DateTimeOffset>(7)));
            }
            else
            {
                avisos.Add(new AvisoRespuesta(
                    lector.GetInt32(1),
                    lector.IsDBNull(2) ? null : lector.GetInt32(2),
                    lector.IsDBNull(3) ? null : lector.GetString(3),
                    lector.GetString(4), lector.GetString(5), lector.GetFieldValue<DateTimeOffset>(7), lector.GetBoolean(8)));
            }
        }
        return new SincronizacionRespuesta(ahora, mensajes, avisos);
    }

    // Devuelve cuántos avisos estaban sin leer. Una lista de ids vacía no marca ninguno.
    public async Task<int> MarcarLeidosAsync(int usuarioId, AvisosLeidosEdicion datos)
    {
        if (datos.Ids != null && datos.Ids.Count == 0 && datos.SolicitudId == null)
        {
            return 0;
        }
        return await _bd.EnTransaccionAsync(usuarioId, async conexion =>
        {
            await using var comando = new NpgsqlCommand(
                "SELECT fn_marcar_avisos_leidos(@usuario, @ids, @solicitud, @otra)", conexion);
            comando.Parameters.AddWithValue("usuario", usuarioId);
            comando.Parameters.Add(new NpgsqlParameter("ids", NpgsqlDbType.Array | NpgsqlDbType.Integer)
            {
                Value = datos.Ids == null ? DBNull.Value : datos.Ids.ToArray()
            });
            comando.Parameters.Add(new NpgsqlParameter("solicitud", NpgsqlDbType.Integer)
            {
                Value = datos.SolicitudId.HasValue ? datos.SolicitudId.Value : DBNull.Value
            });
            comando.Parameters.Add(new NpgsqlParameter("otra", NpgsqlDbType.Integer)
            {
                Value = datos.OtraParteId.HasValue ? datos.OtraParteId.Value : DBNull.Value
            });
            return (int)(await comando.ExecuteScalarAsync())!;
        });
    }

    private async Task<DateTimeOffset> HoraDelServidorAsync()
    {
        await using var comando = _bd.ComandoLectura("SELECT now()");
        // Npgsql entrega timestamptz como DateTime en UTC
        return new DateTimeOffset((DateTime)(await comando.ExecuteScalarAsync())!);
    }
}
