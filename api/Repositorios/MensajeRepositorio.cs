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

    // desde es opcional: null trae todos los mensajes del hilo. otraParteId es el trabajador con quien habla el
    // cliente (opcional si el trabajo ya está asignado; el trabajador no lo necesita).
    public async Task<List<MensajeRespuesta>> ListarAsync(int usuarioId, int solicitudId, DateTimeOffset? desde, int? otraParteId)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT id, emisor_id, emisor_nombre, texto, fecha, es_mio FROM fn_mensajes_de_solicitud(@usuario, @solicitud, @desde, @otro)");
        comando.Parameters.AddWithValue("usuario", usuarioId);
        comando.Parameters.AddWithValue("solicitud", solicitudId);
        comando.Parameters.Add(Fecha("desde", desde));
        comando.Parameters.Add(Entero("otro", otraParteId));

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
            await using var comando = new NpgsqlCommand("SELECT fn_enviar_mensaje(@emisor, @solicitud, @texto::text, @otro)", conexion);
            comando.Parameters.AddWithValue("emisor", emisorId);
            comando.Parameters.AddWithValue("solicitud", solicitudId);
            comando.Parameters.AddWithValue("texto", (object?)datos.Texto ?? DBNull.Value);
            comando.Parameters.Add(Entero("otro", datos.OtraParteId));
            return (int)(await comando.ExecuteScalarAsync())!;
        });
    }

    public async Task<List<ConversacionRespuesta>> ListarConversacionesAsync(int usuarioId)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT solicitud_id, titulo, estado, otra_parte_id, otra_parte_nombre, ultimo_mensaje, fecha_ultimo, " +
            "mensajes_nuevos, abierto FROM fn_conversaciones(@usuario)");
        comando.Parameters.AddWithValue("usuario", usuarioId);

        var conversaciones = new List<ConversacionRespuesta>();
        await using var lector = await comando.ExecuteReaderAsync();
        while (await lector.ReadAsync())
        {
            conversaciones.Add(new ConversacionRespuesta(
                lector.GetInt32(0), lector.GetString(1), lector.GetString(2), lector.GetInt32(3), lector.GetString(4),
                lector.IsDBNull(5) ? null : lector.GetString(5),
                lector.IsDBNull(6) ? null : lector.GetFieldValue<DateTimeOffset>(6),
                lector.GetInt32(7), lector.GetBoolean(8)));
        }
        return conversaciones;
    }

    // Un entero que puede venir vacío, con tipo explícito para que la base elija la función correcta
    private static NpgsqlParameter Entero(string nombre, int? valor)
    {
        return new NpgsqlParameter(nombre, NpgsqlDbType.Integer)
        {
            Value = valor.HasValue ? valor.Value : DBNull.Value
        };
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
