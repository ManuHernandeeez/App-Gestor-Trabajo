using GestorTrabajoApi.Modelos;
using Npgsql;
using NpgsqlTypes;

namespace GestorTrabajoApi.Repositorios;

// Mensajes entre el cliente y el trabajador asignado. Los permisos (ser una de las dos partes, el estado
// del trabajo, el largo del texto) los aplican las funciones de la base.
public class MensajeRepositorio
{
    private readonly BaseDatos _bd;

    public MensajeRepositorio(BaseDatos bd)
    {
        _bd = bd;
    }

    // desde es opcional: null trae todos los mensajes del trabajo
    public async Task<List<MensajeRespuesta>> ListarAsync(int usuarioId, int solicitudId, DateTimeOffset? desde)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT id, emisor_id, emisor_nombre, texto, fecha, es_mio FROM fn_mensajes_de_solicitud(@usuario, @solicitud, @desde)");
        comando.Parameters.AddWithValue("usuario", usuarioId);
        comando.Parameters.AddWithValue("solicitud", solicitudId);
        comando.Parameters.Add(Fecha("desde", desde));

        var mensajes = new List<MensajeRespuesta>();
        await using var lector = await comando.ExecuteReaderAsync();
        while (await lector.ReadAsync())
        {
            mensajes.Add(new MensajeRespuesta(
                lector.GetInt32(0), lector.GetInt32(1), lector.GetString(2), lector.GetString(3),
                lector.GetFieldValue<DateTimeOffset>(4), lector.GetBoolean(5)));
        }
        return mensajes;
    }

    public Task<int> EnviarAsync(int emisorId, int solicitudId, MensajeNuevo datos)
    {
        return _bd.EnTransaccionAsync(emisorId, async conexion =>
        {
            await using var comando = new NpgsqlCommand("SELECT fn_enviar_mensaje(@emisor, @solicitud, @texto::text)", conexion);
            comando.Parameters.AddWithValue("emisor", emisorId);
            comando.Parameters.AddWithValue("solicitud", solicitudId);
            comando.Parameters.AddWithValue("texto", (object?)datos.Texto ?? DBNull.Value);
            return (int)(await comando.ExecuteScalarAsync())!;
        });
    }

    public async Task<List<ConversacionRespuesta>> ListarConversacionesAsync(int usuarioId)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT solicitud_id, titulo, estado, otra_parte_nombre, ultimo_mensaje, fecha_ultimo, mensajes_nuevos " +
            "FROM fn_conversaciones(@usuario)");
        comando.Parameters.AddWithValue("usuario", usuarioId);

        var conversaciones = new List<ConversacionRespuesta>();
        await using var lector = await comando.ExecuteReaderAsync();
        while (await lector.ReadAsync())
        {
            conversaciones.Add(new ConversacionRespuesta(
                lector.GetInt32(0), lector.GetString(1), lector.GetString(2), lector.GetString(3),
                lector.IsDBNull(4) ? null : lector.GetString(4),
                lector.IsDBNull(5) ? null : lector.GetFieldValue<DateTimeOffset>(5),
                lector.GetInt32(6)));
        }
        return conversaciones;
    }

    // timestamptz acepta nulo y siempre en UTC
    private static NpgsqlParameter Fecha(string nombre, DateTimeOffset? valor)
    {
        return new NpgsqlParameter(nombre, NpgsqlDbType.TimestampTz)
        {
            Value = valor.HasValue ? valor.Value.UtcDateTime : DBNull.Value
        };
    }
}
