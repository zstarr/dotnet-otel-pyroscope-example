using DotNetApp.Data;
using DotNetApp.Repositories;
using DotNetApp.Services;
using Microsoft.EntityFrameworkCore;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

// --- OpenTelemetry ---------------------------------------------------------
// Emits traces, metrics, and logs over OTLP. The exporter target is read from
// the standard OTEL_EXPORTER_OTLP_ENDPOINT environment variable (defaulting to
// http://localhost:4317 when unset), so no code change is needed to point the
// app at the inspection proxy running in Docker Compose.
var serviceName = builder.Configuration["OTEL_SERVICE_NAME"] ?? "dot-net-app";

var resourceBuilder = ResourceBuilder.CreateDefault()
    .AddService(serviceName: serviceName, serviceVersion: "1.0.0")
    .AddTelemetrySdk();

builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r
        .AddService(serviceName: serviceName, serviceVersion: "1.0.0")
        .AddTelemetrySdk())
    .WithTracing(tracing => tracing
        .AddSource(DotNetApp.Services.ProductService.ActivitySource.Name)
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddOtlpExporter())
    .WithMetrics(metrics => metrics
        .AddMeter("ProductsController")
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddOtlpExporter());

// Route ILogger output through OpenTelemetry as OTLP logs as well.
builder.Logging.AddOpenTelemetry(logging =>
{
    logging.SetResourceBuilder(resourceBuilder);
    logging.IncludeFormattedMessage = true;
    logging.IncludeScopes = true;
    logging.AddOtlpExporter();
});
// ---------------------------------------------------------------------------

// In-memory EF Core database (the .NET equivalent of an H2 in-memory DB).
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseInMemoryDatabase("ProductsDb"));

// Application layers.
builder.Services.AddScoped<IProductRepository, ProductRepository>();
builder.Services.AddScoped<IProductService, ProductService>();

var app = builder.Build();

// Materialize the in-memory database so HasData seed values are applied.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

// Only force HTTPS redirection outside the container, where an HTTPS endpoint
// is configured. In Docker the app serves plain HTTP behind the compose network.
if (app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseAuthorization();

app.MapControllers();

app.Run();
