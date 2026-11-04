using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;

namespace GestorTrabajoApi.Servicios;

// Crea el administrador al arrancar si no existe, con el correo y la clave de la configuración
// (user-secrets o variables de entorno). Si ya existe no cambia su contraseña.
public static class AdministradorSemilla
{
    public static async Task AsegurarAsync(IServiceProvider servicios)
    {
        var configuracion = servicios.GetRequiredService<IConfiguration>();
        var log = servicios.GetRequiredService<ILoggerFactory>().CreateLogger("AdministradorSemilla");

        var correo = configuracion["Administrador:Correo"];
        var clave = configuracion["Administrador:Clave"];
        if (string.IsNullOrWhiteSpace(correo) || string.IsNullOrEmpty(clave))
        {
            log.LogWarning("Administrador:Correo y Administrador:Clave no están configurados: no se crea el administrador");
            return;
        }
        if (clave.Length < 8)
        {
            throw new InvalidOperationException("Administrador:Clave debe tener al menos 8 caracteres");
        }

        using var alcance = servicios.CreateScope();
        var usuarios = alcance.ServiceProvider.GetRequiredService<UsuarioRepositorio>();
        var hash = alcance.ServiceProvider.GetRequiredService<HashServicio>().Hash(clave);
        var nombre = configuracion["Administrador:Nombre"] ?? "Administrador";

        var creado = await usuarios.AsegurarAdministradorAsync(nombre, correo, hash);
        log.LogInformation(creado ? "Administrador creado: {Correo}" : "El administrador ya existe: {Correo}", correo);
    }
}
