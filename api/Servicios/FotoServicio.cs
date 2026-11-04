namespace GestorTrabajoApi.Servicios;

// Fotos de perfil en la carpeta Fotos/ de la API. En la base solo va el nombre del archivo, que se genera aquí.
public class FotoServicio
{
    public const long Maximo = 2 * 1024 * 1024;

    private static readonly byte[] FirmaJpg = { 0xFF, 0xD8, 0xFF };
    private static readonly byte[] FirmaPng = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

    public string Carpeta { get; }

    public FotoServicio(IWebHostEnvironment entorno)
    {
        Carpeta = Path.Combine(entorno.ContentRootPath, "Fotos");
        Directory.CreateDirectory(Carpeta);
    }

    // Decide por el contenido y no por el nombre ni el tipo que declara quien sube. Devuelve null si no es JPG ni PNG.
    public static string? ExtensionDe(byte[] datos)
    {
        if (Empieza(datos, FirmaJpg))
        {
            return ".jpg";
        }
        return Empieza(datos, FirmaPng) ? ".png" : null;
    }

    // Guarda con un nombre nuevo de 32 caracteres hexadecimales y devuelve ese nombre
    public async Task<string> GuardarAsync(byte[] datos, string extension)
    {
        var nombre = Guid.NewGuid().ToString("N") + extension;
        await File.WriteAllBytesAsync(Path.Combine(Carpeta, nombre), datos);
        return nombre;
    }

    // El nombre sale de la base; se revisa que sea solo un nombre de archivo antes de borrar
    public void Borrar(string? nombre)
    {
        if (string.IsNullOrEmpty(nombre) || nombre != Path.GetFileName(nombre))
        {
            return;
        }
        try
        {
            File.Delete(Path.Combine(Carpeta, nombre));
        }
        catch (IOException)
        {
            // una foto vieja que queda en disco no afecta a nadie
        }
    }

    private static bool Empieza(byte[] datos, byte[] firma)
    {
        return datos.Length >= firma.Length && datos.AsSpan(0, firma.Length).SequenceEqual(firma);
    }
}
