using GestorTrabajoApi.Modelos;
using Npgsql;

namespace GestorTrabajoApi.Repositorios;

// Cuentas: registro, datos para iniciar sesión y estado de la cuenta.
public class UsuarioRepositorio
{
    private readonly BaseDatos _bd;

    public UsuarioRepositorio(BaseDatos bd)
    {
        _bd = bd;
    }

    public Task<int> RegistrarAsync(RegistroSolicitud datos, string passwordHash)
    {
        return _bd.EnTransaccionAsync(null, async conexion =>
        {
            await using var comando = new NpgsqlCommand(
                "SELECT fn_registrar_usuario(@rol::text, @nombre::text, @correo::text, @hash, @telefono::text, " +
                "@dui::text, @municipio::int, @colonia::int, @oficios::int[], @colonias::int[])", conexion);
            comando.Parameters.AddWithValue("rol", Valor(datos.Rol));
            comando.Parameters.AddWithValue("nombre", Valor(datos.Nombre));
            comando.Parameters.AddWithValue("correo", Valor(datos.Correo));
            comando.Parameters.AddWithValue("hash", passwordHash);
            comando.Parameters.AddWithValue("telefono", Valor(datos.Telefono));
            comando.Parameters.AddWithValue("dui", Valor(datos.Dui));
            comando.Parameters.AddWithValue("municipio", Valor(datos.MunicipioId));
            comando.Parameters.AddWithValue("colonia", Valor(datos.ColoniaId));
            comando.Parameters.AddWithValue("oficios", Valor(datos.Oficios));
            comando.Parameters.AddWithValue("colonias", Valor(datos.Colonias));
            return (int)(await comando.ExecuteScalarAsync())!;
        });
    }

    public async Task<CredencialUsuario?> BuscarPorCorreoAsync(string correo)
    {
        await using var comando = _bd.ComandoLectura(
            "SELECT id, rol, nombre, password_hash, estado FROM usuarios " +
            "WHERE lower(correo) = lower(@correo) AND NOT eliminado");
        comando.Parameters.AddWithValue("correo", correo.Trim());
        await using var lector = await comando.ExecuteReaderAsync();
        if (!await lector.ReadAsync())
        {
            return null;
        }
        return new CredencialUsuario(
            lector.GetInt32(0), lector.GetString(1), lector.GetString(2), lector.GetString(3), lector.GetString(4));
    }

    // Devuelve null si el usuario no existe o fue eliminado.
    public async Task<string?> ObtenerEstadoAsync(int usuarioId)
    {
        await using var comando = _bd.ComandoLectura("SELECT estado FROM usuarios WHERE id = @id AND NOT eliminado");
        comando.Parameters.AddWithValue("id", usuarioId);
        return (string?)await comando.ExecuteScalarAsync();
    }

    public Task<bool> AsegurarAdministradorAsync(string nombre, string correo, string passwordHash)
    {
        return _bd.EnTransaccionAsync(null, async conexion =>
        {
            await using var comando = new NpgsqlCommand("SELECT fn_asegurar_administrador(@nombre, @correo, @hash)", conexion);
            comando.Parameters.AddWithValue("nombre", nombre);
            comando.Parameters.AddWithValue("correo", correo);
            comando.Parameters.AddWithValue("hash", passwordHash);
            return (bool)(await comando.ExecuteScalarAsync())!;
        });
    }

    private static object Valor(object? valor)
    {
        return valor ?? DBNull.Value;
    }
}
