using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNet.Builder;
using Microsoft.AspNet.Hosting;
using Microsoft.AspNet.Http;
using Microsoft.Extensions.DependencyInjection;
using System.Text;
using System.Collections;

namespace HelloWorld
{
    public class Startup
    {
        // This method gets called by the runtime. Use this method to add services to the container.
        // For more information on how to configure your application, visit http://go.microsoft.com/fwlink/?LinkID=398940
        public void ConfigureServices(IServiceCollection services)
        {
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app)
        {
            app.UseIISPlatformHandler();
            app.UseStaticFiles();

            app.Run(async (context) =>
            {
                await context.Response.WriteAsync("Hello World!" + Environment.NewLine);

                StringBuilder envVars = new StringBuilder();
                foreach (DictionaryEntry de in Environment.GetEnvironmentVariables())
                    envVars.Append((string)de.Key + ":" + (string)de.Value + "---" + Environment.NewLine);

                try
                {

                    string cloud = Environment.GetEnvironmentVariable("CLOUD_NAME");
                    await context.Response.WriteAsync("Cloud:" + cloud + Environment.NewLine);
                    string machineName = Environment.GetEnvironmentVariable("HOSTNAME");
                    await context.Response.WriteAsync("Host:" + machineName + Environment.NewLine);
                    await context.Response.WriteAsync("EnvVars:" + Environment.NewLine + envVars.ToString());

                }
                catch (Exception ex)
                {
                    await context.Response.WriteAsync(ex.ToString());
                }
            });
        }

        // Entry point for the application.
        public static void Main(string[] args) => WebApplication.Run<Startup>(args);
    }
}
