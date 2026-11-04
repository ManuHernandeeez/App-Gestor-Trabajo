using GestorTrabajoApi.Modelos;
using Npgsql;

namespace GestorTrabajoApi.Repositorios;

// Punto único de acceso a PostgreSQL para los repositorios.
public class BaseDatos
{
    private readonly NpgsqlDataSource _origen;

    public BaseDatos(NpgsqlDataSource origen)
    {
        _origen = origen;
    }

    // Comando de lectura: toma una conexión del pool y la devuelve al cerrar el comando.
    public NpgsqlCommand ComandoLectura(string sql)
    {
        return _origen.CreateCommand(sql);
    }

    // Abre una transacción, fija app.usuario_id para la bitácora y confirma si la acción termina bien.
    // Si la acción lanza una excepción no se confirma nada. Los comandos creados con la conexión
    // que recibe la acción corren dentro de esta transacción.
    public async Task<T> EnTransaccionAsync<T>(int? usuarioId, Func<NpgsqlConnection, Task<T>> accion)
    {
        await using var conexion = await _origen.OpenConnectionAsync();
        await using var transaccion = await conexion.BeginTransactionAsync();

        await using (var fijar = new NpgsqlCommand("SELECT set_config('app.usuario_id', @id, true)", conexion))
        {
            fijar.Parameters.AddWithValue("id", usuarioId?.ToString() ?? "");
            await fijar.ExecuteNonQueryAsync();
        }

        var resultado = await accion(conexion);
        await transaccion.CommitAsync();
        return resultado;
    }

    // Igual que la anterior para acciones que no devuelven nada.
    public Task EnTransaccionAsync(int? usuarioId, Func<NpgsqlConnection, Task> accion)
    {
        return EnTransaccionAsync(usuarioId, async conexion =>
        {
            await accion(conexion);
            return true;
        });
    }

    // Lee una consulta de dos columnas (id, nombre) y cierra el comando.
    public static async Task<List<ElementoCatalogo>> LeerElementosAsync(NpgsqlCommand comando)
    {
        var elementos = new List<ElementoCatalogo>();
        await using (comando)
        await using (var lector = await comando.ExecuteReaderAsync())
        {
            while (await lector.ReadAsync())
            {
                elementos.Add(new ElementoCatalogo(lector.GetInt32(0), lector.GetString(1)));
            }
        }
        return elementos;
    }
}
