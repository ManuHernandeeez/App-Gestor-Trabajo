using GestorTrabajoApi.Modelos;
using Npgsql;

namespace GestorTrabajoApi.Repositorios;

// Calificaciones entre cliente y trabajador, y la reputación de un usuario.
public class CalificacionRepositorio
{
    // Cuántas calificaciones recibidas se devuelven en la reputación
    private const int Ultimas = 10;

    private readonly BaseDatos _bd;

    public CalificacionRepositorio(BaseDatos bd)
    {
        _bd = bd;
    }

    public Task<int> CalificarAsync(int calificadorId, int solicitudId, CalificacionNueva datos)
    {
        return _bd.EnTransaccionAsync(calificadorId, async conexion =>
        {
            await using var comando = new NpgsqlCommand(
                "SELECT fn_calificar(@calificador, @solicitud, @estrellas::int, @comentario::text)", conexion);
            comando.Parameters.AddWithValue("calificador", calificadorId);
            comando.Parameters.AddWithValue("solicitud", solicitudId);
            comando.Parameters.AddWithValue("estrellas", (object?)datos.Estrellas ?? DBNull.Value);
            comando.Parameters.AddWithValue("comentario", (object?)datos.Comentario ?? DBNull.Value);
            return (int)(await comando.ExecuteScalarAsync())!;
        });
    }

    // Devuelve null si el usuario no existe o es el administrador.
    public async Task<ReputacionRespuesta?> ObtenerReputacionAsync(int usuarioId)
    {
        string nombre;
        decimal promedio;
        int total;
        await using (var comando = _bd.ComandoLectura(
            @"SELECT fn_nombre_corto(nombre), promedio_calificacion, total_calificaciones
              FROM usuarios
              WHERE id = @usuario AND NOT eliminado AND rol <> 'administrador'"))
        {
            comando.Parameters.AddWithValue("usuario", usuarioId);
            await using var lector = await comando.ExecuteReaderAsync();
            if (!await lector.ReadAsync())
            {
                return null;
            }
            nombre = lector.GetString(0);
            promedio = lector.GetDecimal(1);
            total = lector.GetInt32(2);
        }
        return new ReputacionRespuesta(nombre, promedio, total, await ListarRecibidasAsync(usuarioId));
    }

    private async Task<List<CalificacionRecibidaRespuesta>> ListarRecibidasAsync(int usuarioId)
    {
        await using var comando = _bd.ComandoLectura(
            @"SELECT c.estrellas, c.comentario, fn_nombre_corto(q.nombre), c.fecha
              FROM calificaciones c
              JOIN usuarios q ON q.id = c.calificador_id
              WHERE c.calificado_id = @usuario
              ORDER BY c.fecha DESC, c.id DESC
              LIMIT @limite");
        comando.Parameters.AddWithValue("usuario", usuarioId);
        comando.Parameters.AddWithValue("limite", Ultimas);

        var calificaciones = new List<CalificacionRecibidaRespuesta>();
        await using var lector = await comando.ExecuteReaderAsync();
        while (await lector.ReadAsync())
        {
            calificaciones.Add(new CalificacionRecibidaRespuesta(
                lector.GetInt32(0), lector.GetString(1), lector.GetString(2), lector.GetFieldValue<DateTimeOffset>(3)));
        }
        return calificaciones;
    }
}
